// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ICleanUSD — $cUSD Sabit Stabilcoin Arayüzü (REBASE YOK)
/// @notice $cUSD = $1.00 flat stabilcoin. Getirisi YOKTUR.
///         Tüm getiri $scUSD ERC-4626 kasasında toplanır (CleanFX motoru).
/// @dev Eski "saniyelik rebase %4.80" modeli SİLİNDİ — Terra-mekanizması riski.
///      Bu arayüz rebase/mint-yield fonksiyonu İÇERMEZ (koda işlenmiş yasak).
interface ICleanUSD {
    /// @notice TVL-Kapılı Sert Değişmez kontrolü.
    /// @return canMint Yeni $cUSD basılabilir mi? (JuniorReserve >= TVL * 3%)
    /// @dev Kural ihlal edilirse mint DURUR. Çıkışlar (burn) ASLA durmaz.
    function canMint() external view returns (bool canMint);

    /// @notice Junior reserve'in TVL'e oranı (basis points, 300 = %3).
    function juniorCoverageBps() external view returns (uint256);

    /// @notice Junior havuzunu besler (ilk zarar teminatlandırması).
    /// @dev Lansmanda kurucu $3.000 tohum → $100k TVL tavanı açar.
    ///      Junior %9.9 kaldıraçlı getiri + borsa komisyonlarıyla organik büyür.
    function seedJunior(uint256 amount) external payable;

    /// @notice Standart ERC-20 dönüştürme fonksiyonları (getiri DAĞITMAZ).
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}
