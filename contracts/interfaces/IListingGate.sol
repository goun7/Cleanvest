// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IListingGate - Cleanvest Listeleme Kapis Arayuzu
/// @notice AegisForge denetimini gecmeden listelemeyi zorunlu kilar.
/// @dev Master sartname: "Odeme ya da listelenme" harac modeli YOK -
///      denetim ZORUNLU'dur ama ucretsiz tarama vardir. Rozet $4.900 ile gelir.
interface IListingGate {
    /// @notice Proje listeleme durumunu dondurur.
    enum ListingStatus {
        None, // basvuru yok
        Pending, // denetim bekliyor
        Verified, // AegisForge tarafindan dogrulandi
        Rejected // kritik acik bulundu, listelenemez
    }

    /// @notice Bir proje icin listeleme basvurusu yapar.
    /// @dev AegisForge denetimini tetikler. Basvuru UCRETSIZDIR (haraç YOK).
    function applyForListing(address projectToken, string calldata projectName) external returns (bytes32 applicationId);

    /// @notice AegisForge motoru tarafindan cagrilir - denetim sonucunu kaydeder.
    /// @dev Yalnizca yetkili AegisForge oracle cagirabilir.
    function recordAuditResult(bytes32 applicationId, bool passed, uint256 cleanScore) external;

    /// @notice Proje listeleme durumunu sorgular (kamusal, ucretsiz).
    function getListingStatus(address projectToken) external view returns (ListingStatus status, uint256 cleanScore);

    /// @notice Verified rozet gecerliligini kontrol eder.
    function isVerified(address projectToken) external view returns (bool);

    /// @notice AegisForge oracle yetkisini gunceller.
    function setAegisForgeOracle(address oracle) external;
}
