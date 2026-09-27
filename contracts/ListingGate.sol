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

    /// @notice Basvuru => taahhuttaki bulgu sayisi (KAMUSAL - sayi gizli degil).
    /// @dev AegisForge cekirdegi PovCommitment.finding_count ile ayni deger.
    mapping(bytes32 => uint256) public commitmentFindingCount;

    /// @notice Basvuru => risk skoru 0-100 (KAMUSAL - CleanScore'dan gelir).
    /// @dev AegisForge cekirdegi PovCommitment.risk_score ile ayni deger.
    ///      Skor gizli degildir; gizli olan yalnizca exploit payload ve tuz'dur.
    mapping(bytes32 => uint8) public commitmentRiskScore;

    /// @notice Basvuru sayaci (gas verimli id uretimi)
    uint256 public applicationCount;

    /// @notice Minimum gecerli CleanScore ebesigi (70/100).
    uint256 public constant MIN_CLEAN_SCORE = 70;

    /// @notice KAMUSAL CleanScore kaydi - AegisForge cekirdeginin
    ///         CleanScoreResponse yapisinin EVM karsiligi.
    /// @dev Sartname: CleanScore KAMUSAL ve UCRETSIZ bir API'dir. Bu yapi
    ///      zincirde okunabilir; gizli degildir. Gizli olan yalnizca PoV
    ///      payload ve tuz'dur.
    struct CleanScoreRecord {
        uint8 score;            // 0-100
        bytes1 grade;           // harf notu (A/B/C)
        uint64 computedAt;      // motor tarafindan hesaplanma timestamp'i
        uint16 findingsCritical;
        uint16 findingsHigh;
        uint16 findingsMedium;
        uint16 findingsLow;
        uint16 findingsInfo;
        bool fullAuditAvailable; // yalnizca $1.490+ kademelerde
    }

    /// @notice Token => EN SON kamusal CleanScore kaydi.
    mapping(address => CleanScoreRecord) public cleanScoreRecords;

    /// @notice Token => tam denetim sunulabilir mi (kademeye bagli).
    /// @dev $199/$399 kademeleri PoV_Hash raporu verir ama payload'a tam erisim YOK.
    ///      $990 ve $4.900 kademeleri tam audit + remediation diff verir.
    mapping(address => bool) public fullAuditAvailable;

    /// @notice Denetim kademesi - AegisForge pricing.rs Tier enum'unun EVM karsiligi.
    /// @dev Musteri sureci: ucretsiz basvuru -> Scan ($199) -> ScanHuman ($399)
    ///      -> FuzzPatch ($990) -> Priority ($4.900). Yalnizca ileri yonlu
    ///      yukseltme (downgrade YOK). Fiyatlar docs/40 H5 Fiyatlandirma Karari
    ///      (2026-09-27) ile guncellendi: insan triyaj opsiyonel kademeye ayrildi.
    enum AuditTier {
        None,        // basvuru yapildi, tarama yok
        Scan,        // $199 - 4 kademe huni + PoV_Hash raporu (otomatik)
        ScanHuman,   // $399 - Scan + INSAN triyaj (opsiyonel, docs/04:90)
        FuzzPatch,   // $990 - Scan + 10k metamorfik fuzz + remediation diff
        Priority     // $4.900 - tumu + formal assurance + 30-gun SLA + oncelik
    }

    /// @notice Token => mevcut denetim kademesi.
    mapping(address => AuditTier) public auditTier;

    /// @notice Token => EN SON basvuru id'si (applicationId timestamp icerir,
    ///         bu yuzden ayri takip sarttir - aksi halde score lookup hatali olur).
    mapping(address => bytes32) public lastApplicationId;

    /// @notice applicationId -> token adresi (audit akisi cozumu).
    /// @dev TEKNIK BORC KAPANDI: once recordAuditResult address(0) emit
    ///      ediyordu (yorum "production'da mapping" diyordu). Artik
    ///      applyForListing sirasinda esleme tutulur.
    mapping(bytes32 => address) public applicationToken;

    /// @notice Kademelerin dolar fiyatları (sent Degil, tam dolar).
    /// @dev Odeme off-chain alinir (fiyat/kripto); zincir yalnizca kademe
    ///      yukseltmesini kaydeder. Haraç modeli YOK: dusuk kademe bile
    ///      listelemeyi engellemez, sirada oncelik kaybettirir.
    ///      Fiyatlar docs/40 (2026-09-27) ile guncellendi: zarar senaryosu
    ///      Scan -$501 -> -$41 (-%92), FuzzPatch -$1510 -> -$510 (-%66).
    uint256 public constant PRICE_SCAN = 199;
    uint256 public constant PRICE_SCAN_HUMAN = 399;
    uint256 public constant PRICE_FUZZ_PATCH = 990;
    uint256 public constant PRICE_PRIORITY = 4900;

    event TierUpgraded(address indexed projectToken, AuditTier fromTier, AuditTier toTier);
    event CleanScorePublished(address indexed projectToken, uint8 score, bytes1 grade);

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
        lastApplicationId[projectToken] = applicationId;
        applicationToken[applicationId] = projectToken;

        listingStatus[projectToken] = ListingStatus.Pending;

        emit ApplicationSubmitted(applicationId, projectToken, projectName);
    }

    /// @inheritdoc IListingGate
    /// @dev Yalnizca AegisForge oracle cagirabilir - merkeziyetsiz доверие.
    function recordAuditResult(bytes32 applicationId, bool passed, uint256 cleanScore) external onlyAegisForge {
        applicationScore[applicationId] = cleanScore;

        // Token adresini applicationToken eslemesinden coz (TEKNIK BORC KAPANDI:
        // eskiden address(0) emit ediliyordu; artik gercek token adresi kullanilir)
        address token = applicationToken[applicationId];
        emit AuditRecorded(applicationId, token, passed, cleanScore);
    }

    /// @notice AegisForge tarafindan cagrilir - token adresi ile birlikte.
    /// @dev Bu fonksiyon gercek audit akisidir. Tam bulgu sayilari KAMUSALDIR.
    function recordAuditResultForToken(
        bytes32 applicationId,
        address projectToken,
        bool passed,
        uint256 cleanScore,
        uint16 findingsCritical,
        uint16 findingsHigh,
        uint16 findingsMedium,
        uint16 findingsLow,
        uint16 findingsInfo,
        bool auditFullAvailable
    ) external onlyAegisForge {
        require(cleanScore <= 100, "Skor 0-100 arasinda olmali");

        applicationScore[applicationId] = cleanScore;

        // KAMUSAL CleanScore kaydini yayimla (ucretsiz API sozu koda islendi)
        cleanScoreRecords[projectToken] = CleanScoreRecord({
            score: uint8(cleanScore),
            grade: _gradeFor(cleanScore),
            computedAt: uint64(block.timestamp),
            findingsCritical: findingsCritical,
            findingsHigh: findingsHigh,
            findingsMedium: findingsMedium,
            findingsLow: findingsLow,
            findingsInfo: findingsInfo,
            fullAuditAvailable: auditFullAvailable
        });
        fullAuditAvailable[projectToken] = auditFullAvailable;

        // Ilk taramada Scan ($299) kademesi varsayilan olarak atanir.
        // Musteri daha sonra upgradeAuditTier ile yukseltir.
        if (auditTier[projectToken] == AuditTier.None) {
            auditTier[projectToken] = AuditTier.Scan;
        }

        if (passed && cleanScore >= MIN_CLEAN_SCORE) {
            listingStatus[projectToken] = ListingStatus.Verified;
            verifiedUntil[projectToken] = type(uint256).max; // Suresiz
        } else {
            listingStatus[projectToken] = ListingStatus.Rejected;
        }

        emit AuditRecorded(applicationId, projectToken, passed, cleanScore);
        emit CleanScorePublished(projectToken, uint8(cleanScore), _gradeFor(cleanScore));
    }

    /// @notice Musteri kademeyi yukseltir - Siparis -> Tarama -> PoV -> Odeme akisi.
    /// @dev Odeme off-chain alinir; bu fonksiyon yalnizca KADEME YUKSELTME kaydeder.
    ///      Sadece ILERI yonlu (downgrade YOK). Haraç YOK: dusuk kademe listelemeyi
    ///      engellemez - sadece siralamada oncelik kaybettirir.
    /// @param projectToken Yükseltilecek proje
    /// @param newTier Hedef kadem (mevcutten yüksek olmalı)
    function upgradeAuditTier(address projectToken, AuditTier newTier) external onlyAegisForge {
        AuditTier current = auditTier[projectToken];
        require(uint256(newTier) > uint256(current), "Yalnizca ileri yonlu yukseltme");
        // Gecersiz kademe kontrolu (defense-in-depth): ABI dekoderi enum
        // sinirlarini zaten dogruladigi icin harici cagrilarda buraya
        // ulasilamaz. Yanlizca guvenlik katmani olarak birakildi.
        require(uint256(newTier) <= uint256(AuditTier.Priority), "Gecersiz kademe");

        auditTier[projectToken] = newTier;

        // FuzzPatch+ kademeleri tam audit (payload + remediation diff) sunar
        if (uint256(newTier) >= uint256(AuditTier.FuzzPatch)) {
            fullAuditAvailable[projectToken] = true;
        }

        emit TierUpgraded(projectToken, current, newTier);
    }

    /// @notice Kademeyi oku (kamusal, ucretsiz).
    function getAuditTier(address projectToken) external view returns (AuditTier) {
        return auditTier[projectToken];
    }

    /// @notice Fiyat kartini zincirde yayimla (seffaf, gizli degil).
    /// @return scan / scanHuman / fuzzPatch / priority dolar fiyatları
    function getPriceCard()
        external
        pure
        returns (uint256 scan, uint256 scanHuman, uint256 fuzzPatch, uint256 priority)
    {
        return (PRICE_SCAN, PRICE_SCAN_HUMAN, PRICE_FUZZ_PATCH, PRICE_PRIORITY);
    }

    /// @notice Harf notu hesapla - AegisForge grade_for ile ayni bantlar.
    /// @dev Kasitli muhafazakar: AAA kazanmak zordur (cekirdek yorumundan alinti).
    function _gradeFor(uint256 score) internal pure returns (bytes1) {
        if (score >= 95) return bytes1("S");  // nadir, muhafazakar
        if (score >= 85) return bytes1("A");
        if (score >= 70) return bytes1("B");  // Verified esigi
        if (score >= 50) return bytes1("C");
        return bytes1("D");
    }

    /// @notice KAMUSAL CleanScore okuma - UCRETSIZ (harc YOK).
    /// @return record Tam kayit: skor, not, bulgu sayilari, tam-audit durumu.
    function getCleanScore(address projectToken)
        external
        view
        returns (CleanScoreRecord memory record)
    {
        return cleanScoreRecords[projectToken];
    }

    /// @inheritdoc IListingGate
    function getListingStatus(address projectToken)
        external
        view
        returns (ListingStatus status, uint256 cleanScore)
    {
        status = listingStatus[projectToken];
        // EN SON basvurudan al (applicationId timestamp icerir, mapping ile takip)
        bytes32 lastApp = lastApplicationId[projectToken];
        cleanScore = applicationScore[lastApp];
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
    /// @param findingCount Kamusal bulgu sayisi (gizli degil)
    /// @param riskScore Kamusal risk skoru 0-100 (gizli degil)
    function sealPovCommitment(
        bytes32 applicationId,
        bytes32 povHash,
        uint256 timestamp,
        uint256 findingCount,
        uint8 riskScore
    ) external onlyAegisForge {
        require(povHash != bytes32(0), "PoV hash sifir olamaz");
        require(timestamp > 0, "Timestamp sifir olamaz");

        povCommitmentHash[applicationId] = povHash;
        commitmentTimestamp[applicationId] = timestamp;
        commitmentFindingCount[applicationId] = findingCount;
        commitmentRiskScore[applicationId] = riskScore;

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
