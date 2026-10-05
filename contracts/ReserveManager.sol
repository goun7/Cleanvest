// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IReserveStrategy.sol";
import "./interfaces/IUtilizationFeed.sol";

/// @title ReserveManager - Cleanvest 3 Kademeli Reserve Yoneticisi
/// @author Cleanvest
/// @notice CleanFXVault'un reserve katmanini yonetir: Aave V3 / OUSG / BUIDL / Prime / idle.
/// @dev Sartname v1.2 (2026-09-24 dogrulanmis veriler):
///      Tier0 (<$250k): %73 Aave(3.78) / %12 idle(0) / %15 Prime(3.30) = 3.254%
///      Tier1 ($250k-12.5M): %40 OUSG(3.44) / %33 Aave / %12 idle / %15 Prime = 3.118%
///      Tier2 (>=$12.5M): %40 BUIDL(3.47) / %33 Aave / %12 idle / %15 Prime = 3.130%
///      OPTIMIZE: %40 OUSG / %42 Aave / %3 float / %15 Prime = 3.459%
///
///      GUVENLI mod (12% idle) VARSAYILAN. OPTIMIZE mod utilization feed'i
///      baglanana kadar ACILAMAZ (sosyallesme riski > %92 utilization).
contract ReserveManager is IReserveStrategy, Ownable, ReentrancyGuard {
    /// @notice USDC (odeme stabilcoini).
    IERC20 public immutable usdc;

    /// @notice Aave V3 Pool (Base) - yield motoru.
    address public aavePool;

    /// @notice Aave Prime Pool - kurumsal likidite.
    address public aavePrimePool;

    /// @notice OUSG (Tier1 RWA) - min $100k baslangic, $5k artis.
    address public ousg;

    /// @notice BUIDL (Tier2 RWA) - min $5M (Qualified Purchaser).
    address public buidl;

    /// @notice TVL esikleri.
    uint256 public constant TIER1_THRESHOLD = 250_000 ether; // OUSG $100k = %40 x $250k
    uint256 public constant TIER2_THRESHOLD = 12_500_000 ether; // BUIDL $5M = %40 x $12.5M

    /// @notice Aave utilization devre-kesici esigi (%92).
    uint256 public constant UTILIZATION_CB_BPS = 9200;

    /// @notice OPTIMIZE mod (SAFE varsayilan).
    bool public optimizeModeEnabled;

    /// @notice Aave utilization feed'i (OPTIMIZE on-sarti).
    address public aaveUtilizationFeed;

    /// @notice Mevcut reserve dagilimi (USDC cinsinden).
    uint256 public aaveBalance;
    uint256 public rwaBalance;
    uint256 public primeBalance;
    uint256 public idleBalance;

    event Rebalanced(ReserveTier tier, uint256 aave, uint256 rwa, uint256 prime, uint256 idle);
    event SuppliedToAave(uint256 amount);
    event WithdrawnFromAave(uint256 amount);
    event OptimizeModeToggled(bool enabled);

    constructor(address _usdc) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
    }

    /// @inheritdoc IReserveStrategy
    function activeTier() public view override returns (ReserveTier tier) {
        uint256 tvl = totalReserve();

        if (optimizeModeEnabled) return ReserveTier.TierOptimize;
        if (tvl >= TIER2_THRESHOLD) return ReserveTier.Tier2;
        if (tvl >= TIER1_THRESHOLD) return ReserveTier.Tier1;
        return ReserveTier.Tier0;
    }

    /// @inheritdoc IReserveStrategy
    /// @notice Kademelerin hedef dagilimi (bps, toplam 10000).
    function targetAllocation(ReserveTier tier) public pure override returns (Allocation memory) {
        if (tier == ReserveTier.Tier0) {
            // %73 Aave / %0 RWA / %15 Prime / %12 idle
            return Allocation(7300, 0, 1500, 1200);
        }
        if (tier == ReserveTier.Tier1) {
            // %40 OUSG / %33 Aave / %15 Prime / %12 idle
            return Allocation(3300, 4000, 1500, 1200);
        }
        if (tier == ReserveTier.Tier2) {
            // %40 BUIDL / %33 Aave / %15 Prime / %12 idle
            return Allocation(3300, 4000, 1500, 1200);
        }
        // OPTIMIZE: %42 Aave / %40 OUSG / %15 Prime / %3 float
        return Allocation(4200, 4000, 1500, 300);
    }

    /// @notice Toplam reserve (tum kollar).
    function totalReserve() public view returns (uint256) {
        return aaveBalance + rwaBalance + primeBalance + idleBalance;
    }

    /// @inheritdoc IReserveStrategy
    /// @notice Reserve'i hedef dagilima getir.
    /// @dev Rebalance yalnizca SAHIP tarafindan tetiklenir (gunluk/haftalik).
    function rebalance() external override onlyOwner nonReentrant {
        ReserveTier tier = activeTier();
        Allocation memory target = targetAllocation(tier);
        uint256 total = totalReserve();

        if (total == 0) return;

        // Hedef miktarlari hesapla
        uint256 targetAave = (total * target.aaveBps) / 10000;
        uint256 targetRwa = (total * target.rwaBps) / 10000;
        uint256 targetPrime = (total * target.primeBps) / 10000;
        uint256 targetIdle = total - targetAave - targetRwa - targetPrime;

        // Basitlestirilmis rebalance: farklari kaydet
        // (Gercek implementasyonda Aave supply/withdraw + RWA mint/redeem)
        aaveBalance = targetAave;
        rwaBalance = targetRwa;
        primeBalance = targetPrime;
        idleBalance = targetIdle;

        emit Rebalanced(tier, targetAave, targetRwa, targetPrime, targetIdle);
    }

    /// @inheritdoc IReserveStrategy
    function supplyToAave(uint256 amount) external override onlyOwner nonReentrant {
        require(amount > 0, "Miktar 0 olamaz");
        require(aavePool != address(0), "Aave pool bagli degil");
        require(idleBalance >= amount, "Yeterli idle USDC yok");

        idleBalance -= amount;
        aaveBalance += amount;

        // USDC'yi Aave pool'a transfer et
        usdc.transfer(aavePool, amount);

        emit SuppliedToAave(amount);
    }

    /// @inheritdoc IReserveStrategy
    function withdrawFromAave(uint256 amount) external override onlyOwner nonReentrant {
        require(amount > 0, "Miktar 0 olamaz");
        require(aavePool != address(0), "Aave pool bagli degil");
        require(aaveBalance >= amount, "Yeterli Aave bakiye yok");

        aaveBalance -= amount;
        idleBalance += amount;

        emit WithdrawnFromAave(amount);
    }

    /// @inheritdoc IReserveStrategy
    /// @notice OPTIMIZE modda utilization > %92 ise devre-kesici aktif.
    /// @dev Anlik itfa T+2'ye duser; SAFE modda her zaman false.
    function utilizationCircuitBreakerActive() external view override returns (bool) {
        if (!optimizeModeEnabled) return false;
        if (aaveUtilizationFeed == address(0)) return false;

        uint256 util = IUtilizationFeed(aaveUtilizationFeed).utilizationBps();
        return util > UTILIZATION_CB_BPS;
    }

    /// @notice Aave pool bagla.
    function setAavePool(address pool) external onlyOwner {
        require(pool != address(0), "Pool sifir olamaz");
        aavePool = pool;
    }

    /// @notice Aave Prime pool bagla.
    function setAavePrimePool(address pool) external onlyOwner {
        aavePrimePool = pool;
    }

    /// @notice OUSG bagla (Tier1 RWA).
    function setOUSG(address token) external onlyOwner {
        ousg = token;
    }

    /// @notice BUIDL bagla (Tier2 RWA).
    function setBUIDL(address token) external onlyOwner {
        buidl = token;
    }

    /// @notice Aave utilization feed bagla (OPTIMIZE on-sarti).
    function setAaveUtilizationFeed(address feed) external onlyOwner {
        aaveUtilizationFeed = feed;
    }

    /// @notice OPTIMIZE modu acar - SADECE utilization feed bagliyken.
    function setOptimizeMode(bool enabled) external onlyOwner {
        if (enabled) {
            require(aaveUtilizationFeed != address(0), "OPTIMIZE: utilization feed bagli degil");
        }
        optimizeModeEnabled = enabled;
        emit OptimizeModeToggled(enabled);
    }

    /// @notice Reserve'e fon ekle (vault deposit'ten).
    function depositReserve(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Miktar 0 olamaz");
        idleBalance += amount;
    }

    /// @notice Reserve'den fon cik (vault redeem icin).
    function withdrawReserve(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Miktar 0 olamaz");
        require(idleBalance >= amount, "Yeterli idle USDC yok");
        idleBalance -= amount;
    }
}
