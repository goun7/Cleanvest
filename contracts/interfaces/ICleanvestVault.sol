// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ICleanvestVault — $scUSD ERC-4626 Getiri Kasası Arayüzü
/// @notice CleanFX yield motoru. REBASE YOK — getiri yalnızca bu kasada toplanır.
/// @dev $cUSD sabit $1.00 flat stabilcoindir (getiri YOK). Getiri = $scUSD kasası.
///      MiCA ART + SEC menkul kıymet zırhı: perakende ABD/AB coğrafi engeli (geoblocking).
interface ICleanvestVault {
    /// @notice Reserve kompozisyon kademeleri (TVL eşiğine göre).
    /// @dev OUSG $100k başlangıç minimumu, BUIDL $5M — Kademe 0'da ikisi de alınamaz.
    enum ReserveTier {
        Tier0, // TVL < $250k:  %73 Aave V3 USDC Base / %12 boş USDC / %15 Aave-Prime
        Tier1, // $250k-$12.5M: %40 OUSG / %33 Aave / %12 boş / %15 Aave-Prime
        Tier2, // >= $12.5M:    %40 direkt BUIDL / %33 Aave / %12 boş / %15 Aave-Prime
        TierOptimize // %3 float + %42 Aave (utilization devre-kesicili, config bayrağı)
    }

    /// @notice TVL'e göre aktif reserve kademini döndürür.
    function activeTier() external view returns (ReserveTier tier);

    /// @notice Kademeye göre dürüst getiri eğrisi (2026-09-24 doğrulanmış veriler).
    /// @return seniorYield Senior ($cUSD) yıllık getiri oranı (1e18 = %100).
    ///         Tier0: %3.05, Tier1: %2.91, Tier2: %2.92, TierOptimize: %3.38-%3.48
    /// @dev "ABD Hazine Bonosu destekli" rozeti yalnızca Tier1+ (TVL >= $250k) gösterilir.
    function currentSeniorYield() external view returns (uint256 seniorYield);

    /// @notice TVL-Kapılı Sert Değişmez (Hard Invariant).
    /// @dev JuniorReserve >= TVL * 3% ihlal edilirse YENİ $cUSD mint'i DURUR.
    ///      Çıkışlar (redemption) ASLA kilitlenmez — yalnızca girişi kilitleriz.
    function juniorCoverageRatio() external view returns (uint256 ratio);

    /// @notice İtfa Kapısı (Redemption Gate).
    /// @dev Günlük arzın %10'una kadar anlık USDC; %10 üstü OUSG/BUIDL banka takası
    ///      için T+2 kuyruğu. Optimize modunda Aave utilization > %92 ise anlık çekimler
    ///      otomatik T+2 kuyruğuna düşer (devre-kesici).
    function redemptionGate() external view returns (uint256 dailyInstantCapPct, uint256 settleDaysAboveCap);

    /// @notice Slippage-korumalı depozito (ERC-4626 inflation attack kalkanı).
    /// @dev Klasik saldırı: saldırgan ilk depozitörün önüne geçer, 1 wei ile 1 pay
    ///      basar, kasaya doğrudan bağış yaparak pay fiyatını şişirir; kurbanın
    ///      depoziti pay alamaz ve saldırgan fonu çeker. minShares ile kullanıcı
    ///      (veya önyüz) convertToShares sonucunu sınır verir; sapmada revert.
    ///      Vaka örnekleri: Cream, Sonne, Resupply (2024-2026).
    function depositWithMin(uint256 assets, address receiver, uint256 minShares)
        external
        returns (uint256 shares);

    /// @notice Slippage-korumalı çıkış (aynı manipülasyona karşı).
    function redeemWithMin(uint256 shares, address receiver, address owner, uint256 minAssets)
        external
        returns (uint256 assets);
}
