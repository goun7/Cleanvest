// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/ICleanvestVault.sol";

/// @title CleanFXVault - $scUSD ERC-4626 Getiri Kasasi
/// @author Cleanvest
/// @notice REBASE YOK - getiri yalnizca bu kasada toplanir.
///         $cUSD = $1.00 flat odeme stabilcoini (getiri YOK).
/// @dev Kilikli Kurallar (master sartname v1.2):
///      1. Reserve kompozisyonu TVL'e gore 3 kademelidir (OUSG/BUIDL minimumlari).
///      2. "Hazine Bonosu destekli" rozeti yalnizca TVL >= $250k (Tier1+) gecerlidir.
///      3. Getiri egrisi 2026-09-24 dogrulanmis verilerle: %3.05 / %2.91 / %2.92.
///      4. Optimize modu config bayragi - Aave utilization feed'i baglanana kadar ACILAMAZ.
contract CleanFXVault is ICleanvestVault, ERC4626, Ownable, ReentrancyGuard {
    /// @notice TVL esikleri (Wei). 1 USD = 1e18.
    uint256 public constant TIER1_THRESHOLD = 250_000 ether; // OUSG $100k min = %40 x $250k
    uint256 public constant TIER2_THRESHOLD = 12_500_000 ether; // BUIDL $5M min = %40 x $12.5M

    /// @notice Optimize modu config bayragi (GUVENLI varsayilan = false).
    /// @dev Aave utilization feed'i baglanana kadar ACILAMAZ.
    bool public optimizeModeEnabled;

    /// @notice Aave utilization devre-kesici esigi (%92 = 9200 bps).
    uint256 public constant UTILIZATION_CB_BPS = 9200;

    /// @notice Aave utilization feed'i (Optimize mod icin zorunlu).
    /// @dev 0 = bagli degil. 0 iken optimizeModeEnabled true olamaz.
    address public aaveUtilizationFeed;

    /// @notice Gunluk anlik itfa kapisi: arzin %10'u.
    uint256 public constant DAILY_INSTANT_CAP_BPS = 1000; // %10

    /// @notice T+2 kuyruk suresi (saniye): 2 gun.
    uint256 public constant T2_SETTLE_SECONDS = 2 days;

    /// @notice Gunluk itfa hacmi takibi (timestamp => miktar).
    mapping(uint256 => uint256) public dailyRedemptions;

    /// @notice T+2 kuyrugu: kullanici => serbest kalma zamani.
    mapping(address => uint256) public queuedRedemptionUnlock;

    constructor(address asset) ERC4626(IERC20(asset)) ERC20("Clean FX Yield", "scUSD") Ownable(msg.sender) {}

    /// @inheritdoc ICleanvestVault
    /// @notice TVL'e gore aktif kademeyi dondurur.
    function activeTier() public view returns (ReserveTier tier) {
        uint256 tvl = totalAssets();

        if (optimizeModeEnabled) return ReserveTier.TierOptimize;
        if (tvl >= TIER2_THRESHOLD) return ReserveTier.Tier2;
        if (tvl >= TIER1_THRESHOLD) return ReserveTier.Tier1;
        return ReserveTier.Tier0;
    }

    /// @inheritdoc ICleanvestVault
    /// @notice Kademeye gore dogrulanmis getiri egrisi (1e18 = %100).
    /// @dev 2026-09-24 verileri: rwa.xyz (BUIDL %3.47), eco.com (OUSG %3.44),
    ///      vaults.fyi (Aave Base %3.78, Prime %3.30). Eski %4.80/%3.9-4.10 SILINDI.
    function currentSeniorYield() external view returns (uint256 seniorYield) {
        ReserveTier tier = activeTier();

        // r_senior = (R - j * r_j) / (1 - j), j = %3, r_j = %9.9 (kaldirac)
        // Yuvarlama: 1e18 = %100, bp = 1e14
        uint256 R_bps; // blended reserve APY (basis points)
        uint256 j_bps = 300; // %3
        uint256 rj_bps = 990; // %9.9

        if (tier == ReserveTier.Tier0) {
            // %73 Aave(378) + %12 idle(0) + %15 Prime(330) = 325.4 bp
            R_bps = 325;
        } else if (tier == ReserveTier.Tier1) {
            // %40 OUSG(344) + %33 Aave(378) + %12 idle(0) + %15 Prime(330) = 311.8 bp
            R_bps = 312;
        } else if (tier == ReserveTier.Tier2) {
            // %40 BUIDL(347) + %33 Aave(378) + %12 idle(0) + %15 Prime(330) = 313.0 bp
            R_bps = 313;
        } else {
            // Optimize: %40 OUSG(344) + %42 Aave(378) + %3 float(0) + %15 Prime(330) = 345.9 bp
            R_bps = 346;
        }

        // r_senior = (R*10000 - j*rj) / (10000 - j)  [bp cinsinden, 1e14'e cevir]
        uint256 senior_bps = (R_bps * 10000 - j_bps * rj_bps) / (10000 - j_bps);
        return senior_bps * 1e14; // 1e18 = %100
    }

    /// @inheritdoc ICleanvestVault
    function juniorCoverageRatio() external pure returns (uint256 ratio) {
        return 300; // %3 (hard invariant, CleanUSD'de uygulanir)
    }

    /// @inheritdoc ICleanvestVault
    function redemptionGate() external pure returns (uint256 dailyInstantCapPct, uint256 settleDaysAboveCap) {
        return (DAILY_INSTANT_CAP_BPS, T2_SETTLE_SECONDS);
    }

    /// @notice Optimize modunu acar - SADECE utilization feed bagliyken.
    /// @dev DERS: feed 0 iken ACILAMAZ (master sartname v1.2 kilidi).
    function setOptimizeMode(bool enabled) external onlyOwner {
        if (enabled) {
            require(aaveUtilizationFeed != address(0), "Optimize: Aave utilization feed bagli degil");
        }
        optimizeModeEnabled = enabled;
    }

    /// @notice Aave utilization feed'ini baglar (Optimize mod on-sarti).
    function setAaveUtilizationFeed(address feed) external onlyOwner {
        aaveUtilizationFeed = feed;
    }

    /// @notice "Hazine Bonosu destekli" rozet gecerliligi.
    /// @dev TVL < $250k'da reserve %100 Aave/USDC - YALAN olur.
    function treasuryBadgeValid() public view returns (bool) {
        return totalAssets() >= TIER1_THRESHOLD;
    }

    /// @notice Aave utilization devre-kesicisi (Optimize modda).
    /// @dev utilization > %92 ise anlik cekimler T+2 kuyruguna duser.
    function _instantRedemptionAllowed() internal view returns (bool) {
        if (!optimizeModeEnabled) return true; // Guvenli modda her zaman anlik
        if (aaveUtilizationFeed == address(0)) return false;

        // Feed'den utilization (bps) oku - harici Chainlink-style feed
        // Bu noktada harici oracle entegrasyonu (ILERIDE)
        return true; // TODO: feed baglaninca utilization > 9200 kontrolu ekle
    }

    /// @notice Cikis kapisi - ASLA kilitlenmez, yalnizca geciktirilir.
    /// @dev Kotanin altinda: anlik. Uzerinde: once requestRedemption() ile
    ///      kuyruga girilir (ayri transaction - revert state'i geri alir),
    ///      2 gun sonra withdraw() basarili olur.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        uint256 today = block.timestamp / 1 days;
        uint256 usedToday = dailyRedemptions[today];

        bool instantAllowed = assets <= _dailyRemainingInstant(usedToday)
            && _instantRedemptionAllowed();

        if (!instantAllowed) {
            uint256 unlock = queuedRedemptionUnlock[owner];
            require(unlock != 0, "Once requestRedemption ile kuyruga girin");
            require(block.timestamp >= unlock, "T+2 bekleme suresi dolmadi");
            // Sure doldu -> kuyruktan temizle, fonlar simdi hareket eder
            delete queuedRedemptionUnlock[owner];
        } else {
            // Anlik USDC cekimi - gunluk %10 kotasi icinde
            dailyRedemptions[today] = usedToday + assets;
        }

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Kotayi asan cikisi T+2 kuyruguna alir (ayri transaction).
    /// @dev Solidity revert state'i geri alir; bu yuzden kuyruk kaydi ayri
    ///      bir cagrida yapilmalidir. CIKIS KILITLENMEZ - 2 gun sonra serbest.
    /// @param assets Cekilecek miktar (gunluk kotayi asiyor olmali)
    function requestRedemption(uint256 assets) external nonReentrant {
        uint256 today = block.timestamp / 1 days;
        uint256 usedToday = dailyRedemptions[today];

        bool instantAllowed = assets <= _dailyRemainingInstant(usedToday)
            && _instantRedemptionAllowed();

        if (!instantAllowed) {
            queuedRedemptionUnlock[msg.sender] = block.timestamp + T2_SETTLE_SECONDS;
            emit RedemptionQueued(msg.sender, assets, block.timestamp + T2_SETTLE_SECONDS);
        } else {
            // Kota icinde - kuyruk GEREKMEZ, anlik cek
            queuedRedemptionUnlock[msg.sender] = 0;
            emit RedemptionInstantEligible(msg.sender, assets);
        }
    }

    /// @notice Kuyruktaki cikisin ne zaman serbest kalacagini dondurur.
    /// @return 0 = kuyrukta degil; >0 = serbest kalma timestamp'i.
    function queuedUnlockTime(address owner) external view returns (uint256) {
        return queuedRedemptionUnlock[owner];
    }

    event RedemptionQueued(address indexed owner, uint256 assets, uint256 unlockTime);
    event RedemptionInstantEligible(address indexed owner, uint256 assets);

    /// @notice Gunluk anlik kalan kotayi hesaplar.
    function _dailyRemainingInstant(uint256 usedToday) internal view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 cap = (supply * DAILY_INSTANT_CAP_BPS) / 10000;
        if (usedToday >= cap) return 0;
        return cap - usedToday;
    }
}
