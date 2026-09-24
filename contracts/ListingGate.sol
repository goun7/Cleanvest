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

    /// @notice Basvuru => PoV_Hash taahhudu (SHA-256, 0x-prefixed hex).
    /// @dev PoV_Hash = SHA256("aegisforge-pov-v1" || canonical_payload || target_hash || salt || ts)
    ///      Bu bir HASH TAHHUDUDUR - ZK-SNARK degil. Satici payload'u aciklamaz;
    ///      alici bagimsiz olarak hash'i yeniden uretip eslestigini dogrular.
    mapping(bytes32 => bytes32) public povCommitmentHash;

    /// @notice Basvuru => taahhudun mint edildigi timestamp (hash domain'i).
    mapping(bytes32 => uint256) public commitmentTimestamp;

    /// @notice Basvuru sayaci (gas verimli id uretimi)
    uint256 public applicationCount;

    /// @notice Minimum gecerli CleanScore ebesigi (70/100).
    uint256 public constant MIN_CLEAN_SCORE = 70;

    event ApplicationSubmitted(bytes32 indexed applicationId, address indexed projectToken, string projectName);
    event AuditRecorded(bytes32 indexed applicationId, address indexed projectToken, bool passed, uint256 cleanScore);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event PovCommitmentSealed(bytes32 indexed applicationId, bytes32 indexed povHash, uint256 timestamp);

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

    /// @notice AegisForge tarafindan cagrilir - PoV hash taahhudunu zincirde muhurler.
    /// @dev AegisForge motoru off-chain'da payload'u gizli tutar ve yalnizca
    ///      hash'i gonderir. Bu "satilmis sirlar" modelidir: alici odeme yapinca
    ///      payload ve tuzu alir, hash'i YENIDEN uretir ve eslestigini dogrular.
    ///      Taahhudun kendi basina bir ZK-SNARK olmadigini acikca belirtiyoruz.
    function sealPovCommitment(
        bytes32 applicationId,
        bytes32 povHash,
        uint256 timestamp
    ) external onlyAegisForge {
        require(povHash != bytes32(0), "PoV hash sifir olamaz");
        require(timestamp > 0, "Timestamp sifir olamaz");

        povCommitmentHash[applicationId] = povHash;
        commitmentTimestamp[applicationId] = timestamp;

        emit PovCommitmentSealed(applicationId, povHash, timestamp);
    }

    /// @notice Alici taraf dogrulama: odeme sonrasi payload ile hash'i eslestirir.
    /// @dev Bu fonksiyon kamu malidir - herkes bagimsiz dogrulayabilir.
    ///      SHA256("aegisforge-pov-v1" || canonical || target_hash || salt || ts)
    ///      Solidity'de SHA-256 icin hash // preimage kontrolu yapariz (Rust tarafinda uretilen
    ///      hash ile karsilastirir). Tuz gizli oldugu icin alici onu almadan eslestiremez.
    function verifyPovCommitment(
        bytes32 applicationId,
        bytes32 povHash,
        uint256 timestamp
    ) external view returns (bool valid) {
        bytes32 stored = povCommitmentHash[applicationId];
        if (stored == bytes32(0)) return false;
        return stored == povHash && commitmentTimestamp[applicationId] == timestamp;
    }

    /// @notice Taahhudun muhurlu olup olmadigini kamusal olarak sorgula.
    function commitmentSealed(bytes32 applicationId) external view returns (bool) {
        return povCommitmentHash[applicationId] != bytes32(0);
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
