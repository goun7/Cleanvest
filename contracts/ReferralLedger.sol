// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ReferralLedger - Referans Sistemi (docs/44)
/// @author Cleanvest
/// @notice Kullanici davet edenleri odullendirir. HyperLiquid modeli:
///         - Referans odulu: %1.25 (arkadasinin ilk \$100K isleminden)
///         - Referans indirimi: %10 komisyon indirim
/// @dev AGIRLIKLI KARAR: Bu kontrat INDEPENDENT - CleanvestSettlement'i
///      DEGISTIRMEZ. Referral kayitlari burada; fee hesaplamasi
///      settlement'ta kalir. Bu, mevcut 201 testin KIRILMAMASINI saglar.
///
///      GUVENLIK:
///      - Referans dongusu reddedilir (A -> B -> A)
///      - Kendine referans reddedilir
///      - Odul tek seferlik (ilk \$100K icin)
///      - onlyOwner ile oduller dagitilir (toplu ozet)
contract ReferralLedger is Ownable {
    /// @notice Referans odulu: %1.25 = 125 (1e-4 birim)
    uint256 public constant REFERRAL_REWARD_PPM = 125;

    /// @notice Referans indirimi: %10 (bazi donusumlere uygulanir)
    uint256 public constant REFERRAL_DISCOUNT_BPS = 100;

    /// @notice Odul suresi: ilk \$100K hacim (1e18 = 1 USD)
    uint256 public constant REWARD_VOLUME_CAP = 100_000 ether;

    /// @notice referrer => referee => baglanti var mi
    mapping(address => mapping(address => bool)) public referralLink;

    /// @notice referee => referrer (kim davet etti)
    mapping(address => address) public referredBy;

    /// @notice referrer => toplam kazanilan odul (1e18 = 1 USD)
    mapping(address => uint256) public referralEarnings;

    /// @notice referrer => davet edilen sayisi
    mapping(address => uint256) public referralCount;

    /// @notice referee => odul tavanina ulasildi mi (tek seferlik)
    mapping(address => bool) public rewardClaimed;

    /// @notice Toplam dagitilan odul (1e18 = 1 USD)
    uint256 public totalRewardDistributed;

    event ReferralRegistered(address indexed referrer, address indexed referee);
    event ReferralRewardDistributed(
        address indexed referrer, address indexed referee, uint256 volume, uint256 reward
    );

    constructor() Ownable(msg.sender) {}

    /// @notice Referans baglantisi olustur (referee kendisi cagirir).
    /// @dev Dongu ve kendine-referans reddedilir. Tek seferlik baglanti.
    function registerReferral(address referrer) external {
        require(referrer != msg.sender, "Kendine referans olmaz");
        require(referrer != address(0), "Referans sifir olamaz");
        require(referredBy[msg.sender] == address(0), "Zaten referansin var");
        require(!referralLink[referrer][msg.sender], "Zaten bagli");

        // Dongu kontrolu: A->B->A olmamali
        require(referredBy[referrer] != msg.sender, "Referans dongusu reddedildi");

        referralLink[referrer][msg.sender] = true;
        referredBy[msg.sender] = referrer;
        referralCount[referrer]++;

        emit ReferralRegistered(referrer, msg.sender);
    }

    /// @notice Hacim gelir referans odulu hesapla (dahili gorunum).
    /// @dev Odul = volume * %1.25 = volume * 125 / 10000
    function _computeReward(uint256 volume) internal pure returns (uint256) {
        return (volume * REFERRAL_REWARD_PPM) / 10_000;
    }

    /// @notice Referans odulunu dagit (sahip - zincirde muhasebe).
    /// @dev Yalnizca referee'nin ilk \$100K hacmi icin odul verilir.
    ///      Referral suresi: referee hacmi \$100K'yi gectiginde durur.
    function distributeReferralReward(address referee, uint256 volume) external onlyOwner {
        address referrer = referredBy[referee];
        require(referrer != address(0), "Referans yok");

        // Tek seferlik: tavan dolunca odul biter
        if (rewardClaimed[referee]) {
            return;
        }

        // Mevcut hacim tavanin altinda: tam odul
        // Tavani asarsa: yalnizca kalan kisim icin odul
        uint256 rewardableVolume = volume;
        if (rewardableVolume > REWARD_VOLUME_CAP) {
            rewardableVolume = REWARD_VOLUME_CAP;
        }

        uint256 reward = _computeReward(rewardableVolume);
        if (reward == 0) return;

        referralEarnings[referrer] += reward;
        totalRewardDistributed += reward;
        rewardClaimed[referee] = true;

        emit ReferralRewardDistributed(referrer, referee, rewardableVolume, reward);
    }

    /// @notice Kullaniciya referans indrimi uygulanir mi?
    function hasReferralDiscount(address referee) external view returns (bool) {
        return referredBy[referee] != address(0) && !rewardClaimed[referee];
    }

    /// @notice Referrer'in davet ve kazanc ozeti.
    function referralSummary(address referrer)
        external
        view
        returns (uint256 count, uint256 earnings)
    {
        return (referralCount[referrer], referralEarnings[referrer]);
    }
}
