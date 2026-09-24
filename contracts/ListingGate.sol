// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IListingGate.sol";

/// @title ListingGate - Cleanvest Listeleme Kapis
/// @author Cleanvest
/// @notice AegisForge denetimini gecmeden hicbir proje listelenemez.
///         Basvuru UCRETSIZDIR; "odeme ya da listelenme" harac modeli YOK.
/// @dev Sartname Kurali: CleanScore kamusal API ucretsizdir. Verified rozeti
///      $4.900 Enterprise kademesi ile gelir ama listeleme engellenmez -
///      sadece siralamada oncelik kazanir.
contract ListingGate is IListingGate, Ownable {
    /// @notice AegisForge oracle adresi (denetim sonuclari buradan gelir).
    address public aegisForgeOracle;

    /// @notice Basvuru => CleanScore (0-100)
    mapping(bytes32 => uint256) public applicationScore;

    /// @notice Token => ListingStatus
    mapping(address => ListingStatus) public listingStatus;

    /// @notice Token => Verified rozet suresi (suresiz = type(uint256).max)
    mapping(address => uint256) public verifiedUntil;

    /// @notice Basvuru sayaci (gas verimli id uretimi)
    uint256 public applicationCount;

    /// @notice Minimum gecerli CleanScore ebesigi (70/100).
    uint256 public constant MIN_CLEAN_SCORE = 70;

    event ApplicationSubmitted(bytes32 indexed applicationId, address indexed projectToken, string projectName);
    event AuditRecorded(bytes32 indexed applicationId, address indexed projectToken, bool passed, uint256 cleanScore);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    constructor() Ownable(msg.sender) {}

    modifier onlyAegisForge() {
        require(msg.sender == aegisForgeOracle, "Yalnizca AegisForge oracle");
        _;
    }

    /// @inheritdoc IListingGate
    function applyForListing(address projectToken, string calldata projectName)
        external
        returns (bytes32 applicationId)
    {
        require(listingStatus[projectToken] == ListingStatus.None || listingStatus[projectToken] == ListingStatus.Rejected,
            "Zaten basvuru var");
        require(projectToken != address(0), "Gecersiz token adresi");

        applicationCount++;
        applicationId = keccak256(abi.encodePacked(projectToken, applicationCount, block.timestamp));

        listingStatus[projectToken] = ListingStatus.Pending;

        emit ApplicationSubmitted(applicationId, projectToken, projectName);
    }

    /// @inheritdoc IListingGate
    /// @dev Yalnizca AegisForge oracle cagirabilir - merkeziyetsiz доверие.
    function recordAuditResult(bytes32 applicationId, bool passed, uint256 cleanScore) external onlyAegisForge {
        applicationScore[applicationId] = cleanScore;

        // Token adresini basvurudan coz (applicationCount ile uretildi)
        // Not: gercek implementasyonda applicationId -> token eslemesi tutulur
        // Bu ornekte emit ile bildirilir; production'da mapping kullanilir
        emit AuditRecorded(applicationId, address(0), passed, cleanScore);
    }

    /// @notice AegisForge tarafindan cagrilir - token adresi ile birlikte.
    /// @dev Bu fonksiyon gercek audit akisidir.
    function recordAuditResultForToken(
        bytes32 applicationId,
        address projectToken,
        bool passed,
        uint256 cleanScore
    ) external onlyAegisForge {
        applicationScore[applicationId] = cleanScore;

        if (passed && cleanScore >= MIN_CLEAN_SCORE) {
            listingStatus[projectToken] = ListingStatus.Verified;
            verifiedUntil[projectToken] = type(uint256).max; // Suresiz
        } else {
            listingStatus[projectToken] = ListingStatus.Rejected;
        }

        emit AuditRecorded(applicationId, projectToken, passed, cleanScore);
    }

    /// @inheritdoc IListingGate
    function getListingStatus(address projectToken)
        external
        view
        returns (ListingStatus status, uint256 cleanScore)
    {
        status = listingStatus[projectToken];
        // Skoru en son basvurudan al (basitlestirilmis)
        cleanScore = applicationScore[keccak256(abi.encodePacked(projectToken, applicationCount))];
        return (status, cleanScore);
    }

    /// @inheritdoc IListingGate
    function isVerified(address projectToken) external view returns (bool) {
        if (listingStatus[projectToken] != ListingStatus.Verified) return false;
        return block.timestamp <= verifiedUntil[projectToken];
    }

    /// @inheritdoc IListingGate
    function setAegisForgeOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "Oracle sifir olamaz");
        address old = aegisForgeOracle;
        aegisForgeOracle = oracle;
        emit OracleUpdated(old, oracle);
    }

    /// @notice Harac modeli YOK - basvuru daima ucretsiz.
    function applicationFee() external pure returns (uint256) {
        return 0; // SIFIR - CleanScore kamusal ve ucretsiz
    }
}
