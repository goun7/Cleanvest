// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/ICleanUSD.sol";

/// @title CleanUSD — $cUSD Sabit Stabilcoin (REBASE YOK)
/// @author Cleanvest
/// @notice $cUSD = $1.00 flat ödeme stabilcoini. Getirisi YOKTUR.
///         Tüm getiri $scUSD ERC-4626 kasasında toplanır (CleanFX motoru).
/// @dev KİLİTLİ KURALLAR (master şartname v1.2):
///      1. REBASE YASAK — Terra-mekanizması ölüm sarmalı riski. Bu kontrat
///         hiçbir rebase/mint-yield fonksiyonu içermez.
///      2. TVL-Kapılı Sert Değişmez: JuniorReserve >= TVL * 3% ihlalinde
///         YENİ MINT DURUR. BURN ASLA DURMAZ (çıkışlar kilitlenmez).
///      3. Lansman tohumu: kurucu $3.000 → $100k TVL tavanı.
contract CleanUSD is ICleanUSD, ERC20, Ownable {
    /// @notice Junior havuzu (ilk zarar teminatlandırması).
    /// @dev Borsa komisyonları + %9.9 kaldıraçlı getiri ile organik büyür.
    uint256 public juniorReserve;

    /// @notice Junior havuzunun TVL'e oranı eşiği (basis points). 300 = %3.
    uint256 public constant JUNIOR_MIN_BPS = 300;

    /// @notice TVL tavanı — tohum sermayesine göre açılır.
    /// @dev $3.000 tohum → $3.000 / 0.03 = $100.000 tavan.
    uint256 public tvlCap;

    /// @notice Tavanın kilitli olup olmadığı (tohum öncesi).
    bool public capUnlocked;

    event JuniorSeeded(address indexed from, uint256 amount);
    event TvlCapRaised(uint256 newCap);
    event MintGateTriggered(uint256 juniorBps, uint256 tvl);

    constructor() ERC20("Clean USD", "cUSD") Ownable(msg.sender) {
        tvlCap = 0; // Tohum öncesi kapalı
        capUnlocked = false;
    }

    /// @inheritdoc ICleanUSD
    /// @notice TVL-Kapılı Sert Değişmez kontrolü.
    /// @dev JuniorReserve >= TVL * 3% değilse mint REDDEDİLİR.
    function canMint() public view returns (bool) {
        if (!capUnlocked) return false; // Tohum yok → kapalı
        uint256 tvl = totalSupply();
        if (tvl == 0) return true;
        // JuniorReserve >= TVL * 3% (basis points: 300/10000)
        return juniorReserve * 10000 >= tvl * JUNIOR_MIN_BPS;
    }

    /// @inheritdoc ICleanUSD
    function juniorCoverageBps() public view returns (uint256) {
        uint256 tvl = totalSupply();
        if (tvl == 0) return type(uint256).max;
        return (juniorReserve * 10000) / tvl;
    }

    /// @inheritdoc ICleanUSD
    /// @notice Junior havuzunu besler ve TVL tavanını açar.
    /// @dev $3.000 tohum → $100.000 tavan ($3.000 / 0.03).
    ///      GUVENLIK: onlyOwner - herkes cagiramaz (DoS onlenur).
    ///      Asiri buyuk tohum reddedilir (canMint icinde carpma tasma riski).
    function seedJunior(uint256 amount) external payable onlyOwner {
        require(msg.value > 0 || amount > 0, "Tohum sifir olamaz");
        uint256 seed = msg.value > 0 ? msg.value : amount;
        // OVERFLOW KORUMASI: juniorReserve * 10000 (canMint icinde) tasmamali
        // 1_000_000 ether = $1M tohum → $33M TVL tavan (gercek disi yuksek)
        require(seed <= 1_000_000 ether, "Tohum cok buyuk (max $1M)");

        juniorReserve += seed;

        if (!capUnlocked) {
            // Tavan = tohum / 0.03 (Tam 3 kat)
            tvlCap = (seed * 10000) / JUNIOR_MIN_BPS;
            capUnlocked = true;
            emit TvlCapRaised(tvlCap);
        }

        emit JuniorSeeded(msg.sender, seed);
    }

    /// @inheritdoc ICleanUSD
    /// @notice Yeni $cUSD basar — SADECE hard invariant sağlanıyorsa.
    /// @dev Kural ihlal edilirse REVERT. Bu, çoklu-katmanlı savunmadır:
    ///      canMint() view kontrolü + mint içinde require.
    ///
    ///      KATMAN SIRASI (önemli): tvlCap kontrolü (L91) canMintAfter'tan
    ///      ÖNCE çalışır. canMintAfter(amount) false <=> newTvl > tvlCap
    ///      olduğundan, bugün tvlCap her zaman bağlayıcıdır ve canMintAfter
    ///      ikinci katman olarak GÖLGELENİR. Bu BILINÇLI defense-in-depth'tir:
    ///      tvlCap mantığı ileride değişse (örn. yönetişim ile cap artırılsa)
    ///      hard invariant (junior >= %3) yine korunur. juniorReserve
    ///      azalamadığından (yalnizca seedJunior ile artar) bu katman bugün
    ///      ölüdür ama kaldırılmaz — güvenlik katmanı olarak kalır.
    function mint(address to, uint256 amount) external {
        require(canMint(), "TVL-Kapili Degismez: Junior <%3, mint kilitli");
        require(totalSupply() + amount <= tvlCap, "TVL tavani asildi");

        if (!canMintAfter(amount)) {
            emit MintGateTriggered(juniorCoverageBps(), totalSupply());
            revert("Bu mint invariant'i ihlal eder");
        }

        _mint(to, amount);
    }

    /// @inheritdoc ICleanUSD
    /// @notice $cUSD yakar — ASLA KİLİTLENMEZ.
    /// @dev Çıkışlar her zaman açıktır. Yalnızca GİRİŞ kilitlenir.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        // Burning, TVL'i düşürür → coverage oranını artırır → mint kapısını açabilir
    }

    /// @notice Mint sonrası invariant hala sağlanıyor mu? (ön-kontrol)
    function canMintAfter(uint256 amount) internal view returns (bool) {
        uint256 newTvl = totalSupply() + amount;
        return juniorReserve * 10000 >= newTvl * JUNIOR_MIN_BPS;
    }

    /// @notice Çıkış kapısı asla kilitli değil (dış okuma için).
    function redemptionsOpen() external pure returns (bool) {
        return true; // Çıkışlar ASLA kilitlenmez
    }
}
