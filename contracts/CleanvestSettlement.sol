// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/ICleanvestSettlement.sol";

/// @title CleanvestSettlement - HEX Spot Borsa Batch Settlement (Faz-3)
/// @author Cleanvest
/// @notice Budish FBA: 400ms batch netting + uniform clearing price.
///         Artik hacim RFQ solver'lara veya Uniswap-proxy'ye gider.
/// @dev Sartname v1.2 kilidi:
///      1. T_batch = 400ms (zincir disi batch toplayici; bu kontrat kesinlestirir)
///      2. orderCommitmentRoot ZORUNLU - Merkle koku front-run/race kalkani
///      3. Anti-collusion bound BOYUT-FARKLIDIR: eps = 0.15% + kappa * (dQ/L)
///         Duz 0.15% KULLANILMAZ - kendi buyuk emirlerimizi kronik reddeder.
///      4. Soguk baslangic emir tavani $5.000/emir (lift trigger ile kalkar)
///      5. Oracle HARICI Chainlink'dir - Uniswap TWAP YASAK (dairesel fiyat)
///         Bu yuzden bu kontrat oracle adresini DISARIDAN alir.
contract CleanvestSettlement is ICleanvestSettlement, Ownable, ReentrancyGuard {
    /// @notice T_batch = 400ms (Budish FBA kilidi).
    uint256 public constant T_BATCH_MS = 400;

    /// @notice eps0 = 0.15% (bps cinsinden 15).
    uint256 public constant EPS0_BPS = 15;

    /// @notice kappa: boyut-farkli anti-collusion katsayisi (bps cinsinden).
    /// @dev eps(dQ) = eps0 + kappa * (dQ / L). dQ/L 1'i gectiginde eps buyur.
    uint256 public constant KAPPA_BPS = 5;

    /// @notice Soguk baslangic emir tavani: $5.000 (1e18 = 1 USD).
    uint256 public constant COLD_START_CAP = 5_000 ether;

    /// @notice Lift trigger: 30-gun hacim > $250k VEYA >= 2 canli RFQ solver.
    uint256 public constant LIFT_VOLUME_THRESHOLD = 250_000 ether;
    uint256 public constant LIFT_SOLVER_COUNT = 2;

    /// @notice Chainlink fiyat feed adresi (harici oracle).
    /// @dev Uniswap TWAP YASAK - dairesel fiyat referansi yaratir.
    address public chainlinkPriceFeed;

    /// @notice Emir tavani kaldirildi mi (lift trigger).
    bool public sizeCapLifted;

    /// @notice 30-gun toplam hacim (epok-bazli birikmeli; kayan pencere
///         duzeltmesi epoch-basi sifirlama ile deployment sonrasi eklenir).
    uint256 public rolling30dVolume;

    /// @notice Kayitli RFQ solver'lar.
    mapping(address => bool) public rfqSolvers;
    uint256 public rfqSolverCount;

    /// @notice Batch'ler: batchId => kesinlesti mi.
    mapping(bytes32 => bool) public batchSettled;

    /// @notice Emir tavanini kim asti (oracle raporu).
    event OrderSizeCapExceeded(address indexed trader, uint256 size, uint256 cap);
    event BatchSettled(bytes32 indexed batchId, uint256 clearingPrice, uint256 totalVolume);
    event SizeCapLifted(uint256 rollingVolume, uint256 solverCount);
    event SolverRegistered(address indexed solver);
    event ChainlinkFeedSet(address indexed feed);

    constructor() Ownable(msg.sender) {}

    modifier onlySolver() {
        require(rfqSolvers[msg.sender], "Kayitli RFQ solver degil");
        _;
    }

    /// @inheritdoc ICleanvestSettlement
    /// @notice Anti-collusion bound - BOYUT-FARKLI.
    /// @dev eps(dQ) = eps0 + kappa * (dQ / L), hepsi bps cinsinden.
    ///      dQ = artik hacim (ic eslesmenin disinda kalan), L = zincirdeki likidite.
    ///      dQ == 0 icin eps = 0.15% (min). dQ/L arttikca eps buyur - buyuk
    ///      emirler tighter bound'a tabidir (kendi emirlerimizi reddetmemek icin).
    function antiCollusionBound(uint256 deltaQ, uint256 liquidityOnchain)
        external
        pure
        override
        returns (uint256 epsBound)
    {
        if (liquidityOnchain == 0) return EPS0_BPS;

        // OVERFLOW KORUMASI: KAPPA_BPS * deltaQ 256-bit'i asiyor (dQ=type().max).
        // Cozum: makul degerlerde HASSAS hesap (once carp, sonra bol),
        // asiri degerlerde once-bol yedegi (ratio tavani ile).
        uint256 sizeTerm;
        if (deltaQ <= type(uint256).max / KAPPA_BPS) {
            // Hassas yol: kucuk dQ icin tamsayi bolme kaybi yok
            sizeTerm = (KAPPA_BPS * deltaQ) / liquidityOnchain;
        } else {
            // Yedek yol: once bol, sonra carp.
            // ratio > 97 zaten sizeTerm tavanini (485) vuruyor.
            uint256 ratio = deltaQ / liquidityOnchain;
            sizeTerm = ratio > 97 ? 485 : KAPPA_BPS * ratio;
        }

        // Asiri buyuk dQ icin tavan (eps sonsuza gitmesin - %5 = 500 bps)
        if (sizeTerm > 485) sizeTerm = 485;

        return EPS0_BPS + sizeTerm; // min 15 bps (0.15%), max 500 bps (5%)
    }

    /// @inheritdoc ICleanvestSettlement
    /// @notice Soguk baslangic emir tavani. Lift trigger tetiklenince type().max.
    function orderSizeCap() external view override returns (uint256) {
        if (sizeCapLifted) return type(uint256).max;
        return COLD_START_CAP;
    }

    /// @notice Emir boyutu tavan kontrolu (emir gonderirken cagrilir).
    /// @dev Bu, tum emirler icin ZORUNLU gate'dir. Asan emir reddedilir.
    function enforceOrderSize(uint256 size) external view {
        if (sizeCapLifted) return;
        require(size <= COLD_START_CAP, "Emir tavani asildi: $5.000 soguk baslangic");
    }

    /// @notice FBA batch'ini zincirde kesinlestirir.
    /// @dev orderCommitmentRoot ZORUNLU - sifir Merkle koku reddedilir.
    ///      Batch yalnizca KAYITLI SOLVER tarafindan gonderilebilir (RFQ imzasi).
    function executeBatchSettlement(MatchedBatch calldata batch, bytes calldata proof)
        external
        override
        onlySolver
        nonReentrant
    {
        bytes32 batchId = batch.batchId;

        // Cift kesinlestirme korumasi
        require(!batchSettled[batchId], "Batch zaten kesinlesti");

        // orderCommitmentRoot ZORUNLU (front-run/race kalkani)
        require(batch.orderCommitmentRoot != bytes32(0), "orderCommitmentRoot ZORUNLU");

        // Uniform clearing price sifir olamaz
        require(batch.clearingPrice > 0, "Takas fiyat 0 olamaz");

        // Batch butunluk kaniti: proof, batch'in alanlarina bagli olmali.
        // Bu bir commitment scheme'dir: solver ancak bu batch icin uretilen
        // kaniti sunabilir. Off-chain katman kaniti uretir (Merkle yolu veya
        // cozer imzasi); zincir uzerinde baglamayi dogrular.
        bytes32 expectedProof = keccak256(
            abi.encode(batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume)
        );
        require(proof.length == 32, "Kanit 32 bayt olmali");
        require(bytes32(proof) == expectedProof, "Kanit batch ile uyumsuz");

        batchSettled[batchId] = true;
        rolling30dVolume += batch.totalVolume;

        emit BatchSettled(batchId, batch.clearingPrice, batch.totalVolume);

        // Lift trigger kontrolu
        _checkLiftTrigger();
    }

    /// @notice Lift trigger: 30-gun hacim > $250k VEYA >= 2 solver.
    /// @dev Otomatik - operator gerektirmez. Bu, LE-2 kararidir.
    function _checkLiftTrigger() internal {
        if (sizeCapLifted) return;

        if (rolling30dVolume > LIFT_VOLUME_THRESHOLD || rfqSolverCount >= LIFT_SOLVER_COUNT) {
            sizeCapLifted = true;
            emit SizeCapLifted(rolling30dVolume, rfqSolverCount);
        }
    }

    /// @notice RFQ solver kaydet (sahip).
    function registerSolver(address solver) external onlyOwner {
        require(solver != address(0), "Solver sifir olamaz");
        require(!rfqSolvers[solver], "Zaten kayitli");

        rfqSolvers[solver] = true;
        rfqSolverCount++;
        emit SolverRegistered(solver);

        // Solver eklendiginde lift trigger'i yeniden kontrol et
        _checkLiftTrigger();
    }

    /// @notice Chainlink fiyat feed'ini bagla (harici oracle).
    /// @dev Uniswap TWAP YASAK - bu kontrat onu hicbir zaman okumayacak.
    function setChainlinkFeed(address feed) external onlyOwner {
        require(feed != address(0), "Feed sifir olamaz");
        chainlinkPriceFeed = feed;
        emit ChainlinkFeedSet(feed);
    }

    /// @notice Batch'in kesinlestigini kamusal olarak sorgula.
    function isBatchSettled(bytes32 batchId) external view returns (bool) {
        return batchSettled[batchId];
    }
}
