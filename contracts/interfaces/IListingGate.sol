// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IListingGate - Cleanvest Listeleme Kapis Arayuzu
/// @notice CleanAudit denetimini gecmeden listelemeyi zorunlu kilar.
/// @dev Master sartname: "Odeme ya da listelenme" harac modeli YOK -
///      denetim ZORUNLU'dur ama ucretsiz tarama vardir. Rozet $4.900 ile gelir.
interface IListingGate {
    /// @notice Proje listeleme durumunu dondurur.
    enum ListingStatus {
        None, // basvuru yok
        Pending, // denetim bekliyor
        Verified, // CleanAudit tarafindan dogrulandi
        Rejected // kritik acik bulundu, listelenemez
    }

    /// @notice Bir proje icin listeleme basvurusu yapar.
    /// @dev CleanAudit denetimini tetikler. Basvuru UCRETSIZDIR (haraç YOK).
    function applyForListing(address projectToken, string calldata projectName)
        external
        returns (bytes32 applicationId);

    /// @notice CleanAudit motoru tarafindan cagrilir - denetim sonucunu kaydeder.
    /// @dev Yalnizca yetkili CleanAudit oracle cagirabilir.
    function recordAuditResult(bytes32 applicationId, bool passed, uint256 cleanScore) external;

    /// @notice Proje listeleme durumunu sorgular (kamusal, ucretsiz).
    function getListingStatus(address projectToken)
        external
        view
        returns (ListingStatus status, uint256 cleanScore);

    /// @notice Verified rozet gecerliligini kontrol eder.
    function isVerified(address projectToken) external view returns (bool);

    /// @notice Denetim kademelerinin dolar fiyat kartini yayimlar (seffaf).
    /// @dev docs/40 (2026-09-27): Scan $199 / ScanHuman $399 / FuzzPatch $990
    ///      / Priority $4.900. Odeme off-chain alinir; zincir yalnizca
    ///      kademeleri ve fiyat seffafligini kaydeder.
    /// @return scan Scan kademesi ($199)
    /// @return scanHuman Scan + insan triyaj kademesi ($399)
    /// @return fuzzPatch FuzzPatch kademesi ($990)
    /// @return priority Priority kademesi ($4.900)
    function getPriceCard()
        external
        view
        returns (uint256 scan, uint256 scanHuman, uint256 fuzzPatch, uint256 priority);

    /// @notice CleanAudit oracle yetkisini gunceller.
    function setCleanAuditOracle(address oracle) external;
}
