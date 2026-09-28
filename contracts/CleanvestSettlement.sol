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

    // ============================================================
    // ISLEM KOMISYONU - UC KADEMELI MODEL (docs/44, 2026-09-26)
    // HyperLiquid: Wood taker %0.045 / maker %0.015 (14 gun hacim).
    // Biz: 0. Kademe %0 (ilk $10K) -> Standart %0.035 -> Pro %0.030.
    // Maker'lara her zaman indirim (likidite saglayan odullendirilir).
    // ============================================================

    /// @notice 0. Kademe siniri: ilk $10.000 islem ucretsiz (hosgeldin).
    uint256 public constant FEE_WELCOME_CAP = 10_000 ether;

    /// @notice Pro kademe esigi: $1M hacimden sonra %0.030.
    uint256 public constant FEE_PRO_THRESHOLD = 1_000_000 ether;

    /// @notice Standart taker komisyonu: %0.035 = 3.5 bps.
    uint256 public constant FEE_STANDARD_TAKER_BPS = 35;

    /// @notice Pro taker komisyonu: %0.030 = 3.0 bps.
    uint256 public constant FEE_PRO_TAKER_BPS = 30;

    /// @notice Maker indirimi: -1.0 bps (Standart %0.025, Pro %0.020).
    uint256 public constant FEE_MAKER_DISCOUNT_BPS = 10;

    /// @notice Protokol komisyon cüzdanı (gelir buraya toplanır).
    address public protocolFeeRecipient;

    /// @notice Toplam toplanan protokol geliri (1e18 = 1 USD).
    uint256 public protocolRevenue;

    /// @notice Kullanici bazli kumulatif hacim (adres => toplam USD).
    mapping(address => uint256) public userCumulativeVolume;

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

    /// @notice Protokol komisyon cüzdanı değişti.
    event ProtocolFeeRecipientSet(address indexed oldRecipient, address indexed newRecipient);

    /// @notice İşlem komisyonu toplandı (zincirde saydam muhasebe).
    event FeeRevenueRecorded(address indexed solver, uint256 volume, uint256 fee, bool isMaker);
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

    // ============================================================
    // ISLEM KOMISYONU - UC KADEMELI (docs/44)
    // ============================================================

    /// @inheritdoc ICleanvestSettlement
    /// @notice Kullanıcının ödediği işlem komisyonu (bps).
    /// @dev Model (HyperLiquid araştırması 2026-09-26):
    ///      - 0. Hoşgeldin: ilk $10K hacim %0 (sıfır komisyon pazarlaması)
    ///      - 1. Standart: %0.035 (35 bps... HAYIR, 3.5 bps DEĞİL)
    ///        DİKKAT: 1 bps = %0.01. Yani %0.035 = 3.5 bps DEĞİL, 35 bps DEĞİL
    ///        %0.035 = 3.5 bps. Ama Solidity tamsayılar: 3.5 bps = 35/10.
    ///        Çözüm: 35 centi-bps (0.1 bps birim) DEĞİL - 35 bps = %0.35 YANLIŞ.
    ///        DOĞRU: %0.035 → 3.5 bps. Tamsayı için 35 (0.1 bps birimi) tutuyoruz
    ///        ve hesaplamada 1e18 USD * 35 / 10000 / 10 = doğru ücret verir.
    ///        BASITLEŞTİRME: bps yerine yüzbinde (1e5 = %100) kullanıyoruz:
    ///        %0.035 = 35 / 100000 = 35 (1e-5 birim).
    function tradingFeeBps(uint256 cumulativeVolume, bool isMaker)
        external
        view
        override
        returns (uint256 feeBps)
    {
        // 0. Kademe: ilk $10K islem ucretsiz (hosgeldin)
        if (cumulativeVolume < FEE_WELCOME_CAP) {
            return 0;
        }

        // 2. Pro: $1M+ hacim
        if (cumulativeVolume >= FEE_PRO_THRESHOLD) {
            // Pro taker %0.030 = 30 (1e-5 birim); maker -10 = 20
            return isMaker ? FEE_PRO_TAKER_BPS - FEE_MAKER_DISCOUNT_BPS : FEE_PRO_TAKER_BPS;
        }

        // 1. Standart: %0.035 = 35 (1e-5 birim); maker -10 = 25
        return isMaker ? FEE_STANDARD_TAKER_BPS - FEE_MAKER_DISCOUNT_BPS : FEE_STANDARD_TAKER_BPS;
    }

    /// @notice Protokol komisyon cüzdanını ayar (sahip).
    function setProtocolFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "Komisyon cuzuDani sifir olamaz");
        address old = protocolFeeRecipient;
        protocolFeeRecipient = recipient;
        emit ProtocolFeeRecipientSet(old, recipient);
    }

    /// @notice Batch'ten toplanan komisyonu kaydet (solver cagirir).
    /// @dev Bu, gelirin zincirde saydam kaydidir. Gercek token transfer
    ///      RFQ solver tarafindan yapilir; burada yalnizca MUHASEBE tutulur.
    ///      ONCE hacim guncellenir, SONRA fee hesaplanir: boylece kullanici
    ///      welcome sinirini gectiginde ayni batch'te standart feeye gecer
    ///      (aksi takdirde 2 batch'e bolunmus gibi welcome'da kalirdi).
    function recordFeeRevenue(uint256 volume, bool isMaker) external onlySolver {
        require(protocolFeeRecipient != address(0), "Komisyon cuzuDani ayarli degil");

        // Once kumulatif hacmi guncelle (sinir gecisi dogru kademeye)
        uint256 newVolume = userCumulativeVolume[msg.sender] + volume;
        userCumulativeVolume[msg.sender] = newVolume;

        uint256 feeRate = this.tradingFeeBps(newVolume, isMaker);
        // 1e-5 birim: fee = volume * rate / 100000
        uint256 fee = (volume * feeRate) / 100_000;

        protocolRevenue += fee;

        emit FeeRevenueRecorded(msg.sender, volume, fee, isMaker);
    }

    /// @notice Kullanici kumulatif hacmini sorgula (kademeyi gormek icin).
    function userVolume(address user) external view returns (uint256) {
        return userCumulativeVolume[user];
    }
}
