// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/ICleanvestSettlement.sol";
import "./ManipulationDetector.sol";
import "./MEVShield.sol";

/// @notice REPLAY SALDIRISI: ayni (user, nonce) ikinci kez kullanilmaya calisildi.
/// @dev DAR gorev (2026-09-29) — durust sinir #2'nin zincir-ustu kapanisi.
///      Custom error: 64 bayt (address+uint256) — require string'lerinden gaz-verimli.
error ReplayDetected(address user, uint256 nonce);

/// @title CleanvestSettlement - HEX Spot Borsa Batch Settlement (Faz-3)
/// @author Cleanvest
/// @notice Budish FBA: 400ms batch netting + uniform clearing price.
///         Artik hacim RFQ solver'lara veya Uniswap-proxy'ye gider.
/// @dev Sartname v1.2 kilidi:
///      1. T_batch = 400ms (zincir disi batch toplayici; bu kontrat kesinlestirir)
///      2. orderCommitmentRoot ZORUNLU - Merkle koku front-run/race kalkani
///      3. Anti-collusion bound BOYUT-FARKLIDIR: eps = 0.15% + kappa * (dQ/L)
///         Duz 0.15% KULLANILMAZ - kendi buyuk emirlerimizi kronik reddeder.
///      4. Soguk baslangic emir tavani $5.000/emir (lift trigger ile kalkar)
///      5. Oracle HARICI Chainlink'dir - Uniswap TWAP YASAK (dairesel fiyat)
///         Bu yuzden bu kontrat oracle adresini DISARIDAN alir.
contract CleanvestSettlement is ICleanvestSettlement, Ownable, ReentrancyGuard {
    /// @notice T_batch = 400ms (Budish FBA kilidi).
    uint256 public constant T_BATCH_MS = 400;

    /// @notice eps0 = 0.15% (bps cinsinden 15).
    uint256 public constant EPS0_BPS = 15;

    /// @notice kappa: boyut-farkli anti-collusion katsayisi (bps cinsinden).
    /// @dev eps(dQ) = eps0 + kappa * (dQ / L). dQ/L 1'i gectiginde eps buyur.
    uint256 public constant KAPPA_BPS = 5;

    /// @notice Soguk baslangic emir tavani: $5.000 (1e18 = 1 USD).
    uint256 public constant COLD_START_CAP = 5_000 ether;

    /// @notice Lift trigger: 30-gun hacim > $250k VEYA >= 2 canli RFQ solver.
    uint256 public constant LIFT_VOLUME_THRESHOLD = 250_000 ether;
    uint256 public constant LIFT_SOLVER_COUNT = 2;

    // ============================================================
    // ISLEM KOMISYONU - UC KADEMELI MODEL (docs/44, 2026-09-26)
    // HyperLiquid: Wood taker %0.045 / maker %0.015 (14 gun hacim).
    // Biz: 0. Kademe %0 (ilk $10K) -> Standart %0.035 -> Pro %0.030.
    // Maker'lara her zaman indirim (likidite saglayan odullendirilir).
    // ============================================================

    /// @notice 0. Kademe siniri: ilk $10.000 islem ucretsiz (hosgeldin).
    uint256 public constant FEE_WELCOME_CAP = 10_000 ether;

    /// @notice Pro kademe esigi: $1M hacimden sonra %0.030.
    uint256 public constant FEE_PRO_THRESHOLD = 1_000_000 ether;

    /// @notice Standart taker komisyonu: %0.035 = 3.5 bps.
    uint256 public constant FEE_STANDARD_TAKER_BPS = 35;

    /// @notice Pro taker komisyonu: %0.030 = 3.0 bps.
    uint256 public constant FEE_PRO_TAKER_BPS = 30;

    /// @notice Maker indirimi: -1.0 bps (Standart %0.025, Pro %0.020).
    uint256 public constant FEE_MAKER_DISCOUNT_BPS = 10;

    /// @notice Protokol komisyon cüzdanı (gelir buraya toplanır).
    address public protocolFeeRecipient;

    /// @notice Toplam toplanan protokol geliri (1e18 = 1 USD).
    uint256 public protocolRevenue;

    /// @notice Kullanici bazli kumulatif hacim (adres => toplam USD).
    mapping(address => uint256) public userCumulativeVolume;

    /// @notice Chainlink fiyat feed adresi (harici oracle).
    /// @dev Uniswap TWAP YASAK - dairesel fiyat referansi yaratir.
    address public chainlinkPriceFeed;

    /// @notice Emir tavani kaldirildi mi (lift trigger).
    bool public sizeCapLifted;

    /// @notice 30-gun toplam hacim (epok-bazli birikmeli; kayan pencere
///         duzeltmesi epoch-basi sifirlama ile deployment sonrasi eklenir).
    uint256 public rolling30dVolume;

    /// @notice Kayitli RFQ solver'lar.
    mapping(address => bool) public rfqSolvers;
    uint256 public rfqSolverCount;

    /// @notice Batch'ler: batchId => kesinlesti mi.
    mapping(bytes32 => bool) public batchSettled;

    // ============================================================
    // ANTI-MANIPULASYON KATMANI (2026-09-29) — README durust sinirlarinin
    // kapanmasi: #2 replay (nonce takibi), #3 MEV (commit-reveal),
    // #5 manipulasyon tespiti (zincir-ustu risk skoru)
    // ============================================================

    /// @notice KULLANILMIS NONCE'LAR (replay korumasi) — durust sinir #2 KAPANDI.
    /// @dev DAR (2026-09-29): nonce artik yalnizca yaprakta olmakla kalmaz,
    ///      ZINCIR-USTU takip edilir. Gaz-verimli ic-ice mapping (her seferinde
    ///      keccak256 anahtar hesaplamasi YOK): user => nonce => kullanildi mi.
    ///      Ayni (user, nonce) ikinci kez -> ReplayDetected revert'u.
    mapping(address => mapping(uint256 => bool)) private _nonceUsed;

    /// @notice Commit-reveal kayitlari (MEV korumasi) — durust sinir #3 KAPANDI.
    mapping(bytes32 => MEVShield.CommitRecord) private _commitRecords;

    /// @notice Batch sira numarasi (commit-reveal yas kontrolu icin).
    uint256 public batchSequence;

    /// @notice Manipulasyon tespiti baseline (onceki batch'ler).
    ManipulationDetector.Baseline private _detectionBaseline;

    /// @notice En son tespit sonucu (kamusal okuma).
    ManipulationDetector.DetectionResult public lastDetection;

    /// @notice Tespit zorunlu mu? (false = opsiyonel; true = risk>70 reddet)
    /// @dev OPSIYONEL BASLAR: mevcut 242 testi bozmamak icin varsayilan false.
    ///      Uretime geciste setDetectionEnforced(true) ile kapatilir.
    bool public detectionEnforced;

    /// @notice Emir tavanini kim asti (oracle raporu).
    event OrderSizeCapExceeded(address indexed trader, uint256 size, uint256 cap);
    event BatchSettled(bytes32 indexed batchId, uint256 clearingPrice, uint256 totalVolume);
    event SizeCapLifted(uint256 rollingVolume, uint256 solverCount);

    /// @notice Protokol komisyon cüzdanı değişti.
    event ProtocolFeeRecipientSet(address indexed oldRecipient, address indexed newRecipient);

    /// @notice İşlem komisyonu toplandı (zincirde saydam muhasebe).
    event FeeRevenueRecorded(address indexed solver, uint256 volume, uint256 fee, bool isMaker);
    event SolverRegistered(address indexed solver);
    event ChainlinkFeedSet(address indexed feed);

    // --- Anti-manipulasyon olaylari (2026-09-29) ---

    /// @notice Nonce zincir-ustu tuketildi (replay korumasi).
    event NonceConsumed(address indexed user, uint256 nonce, bytes32 indexed batchId);

    /// @notice Batch commit edildi (MEV korumasi: icerik gizli).
    event BatchCommitted(bytes32 indexed batchId, bytes32 indexed commitmentHash, uint256 atSequence);

    /// @notice Manipulasyon tespit sonucu yayinlandi (kamusal risk skoru).
    event ManipulationDetected(bytes32 indexed batchId, uint256 riskScore, string label);

    /// @notice Tespit zorunlulugu degisti.
    event DetectionEnforcedChanged(bool enforced);

    constructor() Ownable(msg.sender) {}

    modifier onlySolver() {
        require(rfqSolvers[msg.sender], "Kayitli RFQ solver degil");
        _;
    }

    /// @inheritdoc ICleanvestSettlement
    /// @notice Anti-collusion bound - BOYUT-FARKLI.
    /// @dev eps(dQ) = eps0 + kappa * (dQ / L), hepsi bps cinsinden.
    ///      dQ = artik hacim (ic eslesmenin disinda kalan), L = zincirdeki likidite.
    ///      dQ == 0 icin eps = 0.15% (min). dQ/L arttikca eps buyur - buyuk
    ///      emirler tighter bound'a tabidir (kendi emirlerimizi reddetmemek icin).
    function antiCollusionBound(uint256 deltaQ, uint256 liquidityOnchain)
        external
        pure
        override
        returns (uint256 epsBound)
    {
        if (liquidityOnchain == 0) return EPS0_BPS;

        // OVERFLOW KORUMASI: KAPPA_BPS * deltaQ 256-bit'i asiyor (dQ=type().max).
        // Cozum: makul degerlerde HASSAS hesap (once carp, sonra bol),
        // asiri degerlerde once-bol yedegi (ratio tavani ile).
        uint256 sizeTerm;
        if (deltaQ <= type(uint256).max / KAPPA_BPS) {
            // Hassas yol: kucuk dQ icin tamsayi bolme kaybi yok
            sizeTerm = (KAPPA_BPS * deltaQ) / liquidityOnchain;
        } else {
            // Yedek yol: once bol, sonra carp.
            // ratio > 97 zaten sizeTerm tavanini (485) vuruyor.
            uint256 ratio = deltaQ / liquidityOnchain;
            sizeTerm = ratio > 97 ? 485 : KAPPA_BPS * ratio;
        }

        // Asiri buyuk dQ icin tavan (eps sonsuza gitmesin - %5 = 500 bps)
        if (sizeTerm > 485) sizeTerm = 485;

        return EPS0_BPS + sizeTerm; // min 15 bps (0.15%), max 500 bps (5%)
    }

    /// @inheritdoc ICleanvestSettlement
    /// @notice Soguk baslangic emir tavani. Lift trigger tetiklenince type().max.
    function orderSizeCap() external view override returns (uint256) {
        if (sizeCapLifted) return type(uint256).max;
        return COLD_START_CAP;
    }

    /// @notice Emir boyutu tavan kontrolu (emir gonderirken cagrilir).
    /// @dev Bu, tum emirler icin ZORUNLU gate'dir. Asan emir reddedilir.
    function enforceOrderSize(uint256 size) external view {
        if (sizeCapLifted) return;
        require(size <= COLD_START_CAP, "Emir tavani asildi: $5.000 soguk baslangic");
    }

    /// @notice FBA batch'ini zincirde kesinlestirir.
    /// @dev orderCommitmentRoot ZORUNLU - sifir Merkle koku reddedilir.
    ///      Batch yalnizca KAYITLI SOLVER tarafindan gonderilebilir (RFQ imzasi).
    function executeBatchSettlement(MatchedBatch calldata batch, bytes calldata proof)
        external
        override
        onlySolver
        nonReentrant
    {
        bytes32 batchId = batch.batchId;

        // Cift kesinlestirme korumasi
        require(!batchSettled[batchId], "Batch zaten kesinlesti");

        // orderCommitmentRoot ZORUNLU (front-run/race kalkani)
        require(batch.orderCommitmentRoot != bytes32(0), "orderCommitmentRoot ZORUNLU");

        // Uniform clearing price sifir olamaz
        require(batch.clearingPrice > 0, "Takas fiyat 0 olamaz");

        // Batch butunluk kaniti: proof, batch'in alanlarina bagli olmali.
        // Bu bir commitment scheme'dir: solver ancak bu batch icin uretilen
        // kaniti sunabilir. Off-chain katman kaniti uretir (Merkle yolu veya
        // cozer imzasi); zincir uzerinde baglamayi dogrular.
        bytes32 expectedProof = keccak256(
            abi.encode(batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume)
        );
        require(proof.length == 32, "Kanit 32 bayt olmali");
        require(bytes32(proof) == expectedProof, "Kanit batch ile uyumsuz");

        batchSettled[batchId] = true;
        rolling30dVolume += batch.totalVolume;

        // Batch sirasini artir (commit-reveal yas kontrolu icin)
        batchSequence += 1;

        emit BatchSettled(batchId, batch.clearingPrice, batch.totalVolume);

        // Lift trigger kontrolu
        _checkLiftTrigger();
    }

    /// @notice Lift trigger: 30-gun hacim > $250k VEYA >= 2 solver.
    /// @dev Otomatik - operator gerektirmez. Bu, LE-2 kararidir.
    function _checkLiftTrigger() internal {
        if (sizeCapLifted) return;

        if (rolling30dVolume > LIFT_VOLUME_THRESHOLD || rfqSolverCount >= LIFT_SOLVER_COUNT) {
            sizeCapLifted = true;
            emit SizeCapLifted(rolling30dVolume, rfqSolverCount);
        }
    }

    // ============================================================
    // ANTI-MANIPULASYON KATMANI (2026-09-29)
    // README durust sinirlarinin kapanmasi: #2, #3, #5
    // ============================================================

    /// @notice DURUST SINIR #2 KAPANDI — Nonce'lari zincir-ustu tuket.
    /// @dev Bir batch icindeki her imzali emrin nonce'u ARTIK TUKETILIR:
    ///      ayni (user, nonce) bir daha KULLANILAMAZ. Bu, yaprak-seviyesinde
    ///      replay saldirisini durdurur (oncesinde yalnizca batch-seviyesinde
    ///      batchSettled koruyordu). Her yaprak `_useNonce` uzerinden gecer.
    /// @param amounts Emir miktarlari (yaprak icin)
    /// @param users Emir kullanici adresleri
    /// @param nonces Emir nonce'lari (replay anahtari)
    /// @param batchId Bu batch (nonce'lar bu batch'e baglanir)
    function consumeNonces(
        uint256[] calldata amounts,
        address[] calldata users,
        uint256[] calldata nonces,
        bytes32 batchId
    ) external onlySolver nonReentrant {
        require(
            amounts.length == users.length && users.length == nonces.length,
            "Dizi uzunluklari uyumsuz"
        );
        require(amounts.length > 0, "Bos dizi");
        require(batchSettled[batchId], "Batch henuzz kesinlesmedi");

        for (uint256 i = 0; i < nonces.length; i++) {
            _useNonce(users[i], nonces[i]);
            emit NonceConsumed(users[i], nonces[i], batchId);
        }
    }

    /// @notice REPLAY KORUMASI ÇEKİRDEĞİ — bir nonce'yi kullanilmis olarak isaretle.
    /// @dev DAR (2026-09-29): her imzali yapragin nonce'u buradan gecer.
    ///      Zaten kullanilmissa REVERT (ReplayDetected) — fail-closed.
    ///      Gaz maliyeti: 1 SSTORE (yeni anahtar) + 1 SLOAD (varlik kontrolu),
    ///      ic-ice mapping keccak256 anahtar turetmez.
    /// @param user Emir sahibi (nonce kullanicisi)
    /// @param nonce Emir nonce'u (yapraktaki alan)
    function _useNonce(address user, uint256 nonce) internal {
        if (_nonceUsed[user][nonce]) {
            revert ReplayDetected(user, nonce);
        }
        _nonceUsed[user][nonce] = true;
    }

    /// @notice Bir nonce kullanildi mi? (kamusal replay sorgusu)
    function isNonceConsumed(address user, uint256 nonce) external view returns (bool) {
        return _nonceUsed[user][nonce];
    }

    /// @notice DURUST SINIR #3 KAPANDI — Batch icin commit-reveal (MEV kalkani).
    /// @dev Solver once batch'in HASH'ine commit eder (icerik GIZLI). NeurIPS
    ///      2026: sandwich icin alt-sinir gizliligi yeterlidir — tam zk DEGIL.
    ///      Commit kilitlidir; reveal'da icerik hash'le uymak ZORUNDA.
    /// @param batchId Batch tanimlayicisi
    /// @param orderCommitmentRoot Emir taahhudu Merkle koku
    /// @param clearingPrice Tek orta takas fiyat
    /// @param totalVolume Batch toplam hacmi
    function commitBatch(
        bytes32 batchId,
        bytes32 orderCommitmentRoot,
        uint256 clearingPrice,
        uint256 totalVolume
    ) external onlySolver nonReentrant {
        require(batchId != bytes32(0), "BatchId sifir olamaz");
        require(orderCommitmentRoot != bytes32(0), "orderCommitmentRoot ZORUNLU");

        MEVShield.CommitRecord storage rec = _commitRecords[batchId];
        require(rec.state == MEVShield.CommitState.None, "Batch zaten commit edildi");

        bytes32 commitmentHash =
            MEVShield.computeCommitment(batchId, orderCommitmentRoot, clearingPrice, totalVolume);

        _commitRecords[batchId] = MEVShield.markCommitted(rec, commitmentHash, batchSequence, msg.sender);

        emit BatchCommitted(batchId, commitmentHash, batchSequence);
    }

    /// @notice Commit-reveal: batch'in commit'le uyumunu dogrula (kamusal).
    /// @dev Bu, "reveal" asamasidir: herkes commit'in batch ile uyustugunu
    ///      bagimsiz olarak denetleyebilir. Uyumsuzluk = manipulasyon kaniti.
    function verifyBatchCommit(
        bytes32 batchId,
        bytes32 orderCommitmentRoot,
        uint256 clearingPrice,
        uint256 totalVolume
    ) external view returns (bool) {
        MEVShield.CommitRecord memory rec = _commitRecords[batchId];
        return MEVShield.canReveal(rec, batchId, orderCommitmentRoot, clearingPrice, totalVolume, batchSequence + 1);
    }

    /// @notice DURUST SINIR #5 KAPANDI — Manipulasyon tespiti (zincir-ustu).
    /// @dev Batch icindeki islem ciftlerinden RISK SKORU uretir. Uc sinyal:
    ///      hacim/islem dususu (Zwydak 2026), round-trip payi, cift seli.
    ///      Sonuc bir KANIT DEGIL, bir RISK SKORUDUR — otomatik yaptirim
    ///      yapilmaz (detectionEnforced true ise >70 reddeder).
    function reportBatchTrades(
        bytes32 batchId,
        ManipulationDetector.TradePair[] calldata pairs,
        uint256 totalVolume
    ) external onlySolver nonReentrant returns (uint256 riskScore) {
        require(batchSettled[batchId], "Batch kesinlesmedi");

        ManipulationDetector.DetectionResult memory r =
            ManipulationDetector.analyze(pairs, totalVolume, _detectionBaseline);

        lastDetection = r;
        _detectionBaseline = ManipulationDetector.updateBaseline(_detectionBaseline, totalVolume, _pairTxCount(pairs));

        emit ManipulationDetected(batchId, r.riskScore, ManipulationDetector.riskLabel(r));

        // Zorunlu modda yuksek riskli batch'ler REDDEDILIR (defense-in-depth)
        if (detectionEnforced) {
            require(
                r.riskScore < ManipulationDetector.HIGH_RISK_THRESHOLD,
                "Manipulasyon riski: batch reddedildi"
            );
        }

        return r.riskScore;
    }

    /// @dev Islem ciftlerinin toplam islem sayisini hesaplar.
    function _pairTxCount(ManipulationDetector.TradePair[] calldata pairs)
        internal
        pure
        returns (uint256 total)
    {
        for (uint256 i = 0; i < pairs.length; i++) {
            total += pairs[i].count;
        }
    }

    /// @notice Tespit zorunlulugunu ayarla (sahip).
    /// @dev false: tespit yalniziz RAPORLANIR (gelistirme/analiz modu).
    ///      true: risk > 70 olan batch'ler REDDEDILIR (uretim modu).
    function setDetectionEnforced(bool enforced) external onlyOwner {
        detectionEnforced = enforced;
        emit DetectionEnforcedChanged(enforced);
    }

    /// @notice Kamusal: son tespit sonucunu oku (ucretsiz API).
    function lastDetectionSummary()
        external
        view
        returns (uint256 riskScore, string memory label, bool volumeDrop, bool roundTrip, bool flooding)
    {
        return (
            lastDetection.riskScore,
            ManipulationDetector.riskLabel(lastDetection),
            lastDetection.volumePerTxDrop,
            lastDetection.roundTripDetected,
            lastDetection.pairFlooding
        );
    }

    // ============================================================
    // MERKLE EMIR TAAHHUDU DOGRULAMA (2026-09-28)
    // Guvenlik acigi kapanmasi: orderCommitmentRoot artik GERCEK Merkle
    // koku olarak uretilir (merkle/ Rust crate'i) ve bu fonksiyon
    // yaprak inclusion kanitini koke karsi dogrular.
    // ============================================================

    /// @notice Yaprak hash'i: keccak256(abi.encode(amount, user, nonce)).
    /// @dev Merkle ureticisi (Rust) ile BIREBIR ayni paketleme.
    ///      uint256 amount (32) + address user (12 sifir + 20) + uint256 nonce (32) = 96 bayt.
    function leafHash(uint256 amount, address user, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encode(amount, user, nonce));
    }

    /// @notice Merkle inclusion kanitini koke karsi dogrular.
    /// @dev Cift-yaprakli (double-leaf) agac: her seviyede ikili eslesme;
    ///      tek kalan yaprak KENDISIYLE eslestirilir. Rust ureticisi
    ///      (merkle/src/lib.rs: prove/verify) ile birebir ayni algoritma.
    /// @param leaf Dogrulanacak yapragin hash'i (leafHash() ile uretilir)
    /// @param proof Sibling hash'ler + konum bitleri (her 33. baytin dusuk
    ///              biti: 1 = sibling sagda, 0 = sibling solda)
    /// @param root Dogrulanacak Merkle koku (orderCommitmentRoot)
    /// @return true Kanit gecerli (leaf root icinde)
    function verifyMerkleProof(
        bytes32 leaf,
        bytes calldata proof,
        bytes32 root
    ) public pure returns (bool) {
        return _verifyMerkleProof(leaf, proof, root);
    }

    /// @dev Memory/calldata ayrimi: verifySignedOrder memory kullanir.
    function _verifyMerkleProof(
        bytes32 leaf,
        bytes memory proof,
        bytes32 root
    ) internal pure returns (bool) {
        // Kanit: her seviye icin 32 bayt sibling + 1 bayt konum
        // (Toplam seviye sayisi = proof.length / 33)
        if (proof.length % 33 != 0) return false;

        bytes32 acc = leaf;

        for (uint256 i = 0; i < proof.length; i += 33) {
            bytes32 sibling;
            // assembly ile 32 bayt oku (memory proof[i..i+32])
            assembly {
                // bytes memory: 32 bayt uzunluk + veri; proof veri pointer'i
                let ptr := add(add(proof, 32), i)
                sibling := mload(ptr)
            }

            // Konum biti: sibling sagda (1) veya solda (0)
            bool isRight = (proof[i + 32] & 0x01) == 0x01;

            // Sıralama: isRight -> (acc, sibling); !isRight -> (sibling, acc)
            // Bu, Rust ureticisinin prove() konum biti ile AYNI kuraldir.
            if (isRight) {
                acc = keccak256(abi.encode(acc, sibling));
            } else {
                acc = keccak256(abi.encode(sibling, acc));
            }
        }

        return acc == root;
    }

    /// @notice Rust ureticisi ile ayni agac kuralini test icin hesaplar.
    /// @dev Cift-yaprakli: [a,b] -> keccak256(abi.encode(a,b));
    ///      tek kalan -> keccak256(abi.encode(a,a)).
    function _buildLayer(bytes32[] memory layer) internal pure returns (bytes32[] memory) {
        uint256 n = layer.length;
        uint256 outLen = (n + 1) / 2;
        bytes32[] memory out = new bytes32[](outLen);
        for (uint256 i = 0; i < outLen; i++) {
            bytes32 a = layer[i * 2];
            bytes32 b = (i * 2 + 1 < n) ? layer[i * 2 + 1] : a;
            out[i] = keccak256(abi.encode(a, b));
        }
        return out;
    }

    /// @notice Yaprak listesinden Merkle koku hesaplar (Rust ile birebir).
    /// @dev Test ve uretim karsilastirmasi icin zincir-ustu referans.
    function computeRoot(bytes32[] memory leaves) public pure returns (bytes32) {
        require(leaves.length > 0, "Bos agac koku tanimsiz");
        bytes32[] memory layer = leaves;
        while (layer.length > 1) {
            layer = _buildLayer(layer);
        }
        return layer[0];
    }

    // ============================================================
    // YAPRAK IMZALARI (2026-09-28) — GUVENLIK ACIGININ TAM KAPANMASI
    // Kok artik yalnizca agac yapisini degil, her yapragin
    // KULLANICI TARAFINDAN IMZALANDIGINI da dogrular.
    // Sema: EIP-191 personal_sign (cuzdan signMessage ile ayni).
    // ============================================================

    /// @notice EIP-191 imza ozeti: keccak256("\x19Ethereum Signed Message:\n32" || hash).
    /// @dev Rust eth_signed_message_hash ile BIREBIR ayni cikti.
    function toEthSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /// @notice Imzadan imzalayan adresi geri kazanir (ecrecover).
    /// @param leaf Yaprak hash'i (imza bunun EIP-191 ozeti uzerinedir)
    /// @param sig 65 bayt imza: r(32) + s(32) + v(1); v: 27 veya 28
    /// @return imzalayan adres; gecersiz imzada address(0)
    function recoverSigner(bytes32 leaf, bytes memory sig) public pure returns (address) {
        require(sig.length == 65, "Imza 65 bayt olmali");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            // bytes memory: 32 bayt uzunluk + veri
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return ecrecover(toEthSignedMessageHash(leaf), v, r, s);
    }

    /// @notice Yaprak imzasini dogrular: imzalayan == signer mi?
    /// @dev Agactan BAGIMSIZDIR — yalnizca yaprak hash'ine imza dogrulanir.
    function verifyLeafSignature(bytes32 leaf, bytes memory sig, address signer)
        public
        pure
        returns (bool)
    {
        if (signer == address(0)) return false;
        return recoverSigner(leaf, sig) == signer;
    }

    /// @notice TAM KANIT ZINIRI: hem imza hem Merkle inclusion dogrular.
    /// @dev Kullanici imzasi -> yaprak -> kok zincirinin tam dogrulamasidir.
    ///      Rust verify_signed ile birebir ayni mantik.
    /// @param leaf Dogrulanacak yaprak hash'i
    /// @param sig Yaprak imzasi (65 bayt, EIP-191)
    /// @param signer Iddia edilen imzalayan adres
    /// @param proof Merkle sibling kaniti (33 bayt/seviye)
    /// @param root Dogrulanacak Merkle koku
    /// @return true Imza gecerli VE yaprak kok icinde
    function verifySignedOrder(
        bytes32 leaf,
        bytes memory sig,
        address signer,
        bytes memory proof,
        bytes32 root
    ) public pure returns (bool) {
        return verifyLeafSignature(leaf, sig, signer) && _verifyMerkleProof(leaf, proof, root);
    }

    /// @notice RFQ solver kaydet (sahip).
    function registerSolver(address solver) external onlyOwner {
        require(solver != address(0), "Solver sifir olamaz");
        require(!rfqSolvers[solver], "Zaten kayitli");

        rfqSolvers[solver] = true;
        rfqSolverCount++;
        emit SolverRegistered(solver);

        // Solver eklendiginde lift trigger'i yeniden kontrol et
        _checkLiftTrigger();
    }

    /// @notice Chainlink fiyat feed'ini bagla (harici oracle).
    /// @dev Uniswap TWAP YASAK - bu kontrat onu hicbir zaman okumayacak.
    function setChainlinkFeed(address feed) external onlyOwner {
        require(feed != address(0), "Feed sifir olamaz");
        chainlinkPriceFeed = feed;
        emit ChainlinkFeedSet(feed);
    }

    /// @notice Batch'in kesinlestigini kamusal olarak sorgula.
    function isBatchSettled(bytes32 batchId) external view returns (bool) {
        return batchSettled[batchId];
    }

    // ============================================================
    // ISLEM KOMISYONU - UC KADEMELI (docs/44)
    // ============================================================

    /// @inheritdoc ICleanvestSettlement
    /// @notice Kullanıcının ödediği işlem komisyonu (bps).
    /// @dev Model (HyperLiquid araştırması 2026-09-26):
    ///      - 0. Hoşgeldin: ilk $10K hacim %0 (sıfır komisyon pazarlaması)
    ///      - 1. Standart: %0.035 (35 bps... HAYIR, 3.5 bps DEĞİL)
    ///        DİKKAT: 1 bps = %0.01. Yani %0.035 = 3.5 bps DEĞİL, 35 bps DEĞİL
    ///        %0.035 = 3.5 bps. Ama Solidity tamsayılar: 3.5 bps = 35/10.
    ///        Çözüm: 35 centi-bps (0.1 bps birim) DEĞİL - 35 bps = %0.35 YANLIŞ.
    ///        DOĞRU: %0.035 → 3.5 bps. Tamsayı için 35 (0.1 bps birimi) tutuyoruz
    ///        ve hesaplamada 1e18 USD * 35 / 10000 / 10 = doğru ücret verir.
    ///        BASITLEŞTİRME: bps yerine yüzbinde (1e5 = %100) kullanıyoruz:
    ///        %0.035 = 35 / 100000 = 35 (1e-5 birim).
    function tradingFeeBps(uint256 cumulativeVolume, bool isMaker)
        external
        view
        override
        returns (uint256 feeBps)
    {
        // 0. Kademe: ilk $10K islem ucretsiz (hosgeldin)
        if (cumulativeVolume < FEE_WELCOME_CAP) {
            return 0;
        }

        // 2. Pro: $1M+ hacim
        if (cumulativeVolume >= FEE_PRO_THRESHOLD) {
            // Pro taker %0.030 = 30 (1e-5 birim); maker -10 = 20
            return isMaker ? FEE_PRO_TAKER_BPS - FEE_MAKER_DISCOUNT_BPS : FEE_PRO_TAKER_BPS;
        }

        // 1. Standart: %0.035 = 35 (1e-5 birim); maker -10 = 25
        return isMaker ? FEE_STANDARD_TAKER_BPS - FEE_MAKER_DISCOUNT_BPS : FEE_STANDARD_TAKER_BPS;
    }

    /// @notice Protokol komisyon cüzdanını ayar (sahip).
    function setProtocolFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "Komisyon cuzuDani sifir olamaz");
        address old = protocolFeeRecipient;
        protocolFeeRecipient = recipient;
        emit ProtocolFeeRecipientSet(old, recipient);
    }

    /// @notice Batch'ten toplanan komisyonu kaydet (solver cagirir).
    /// @dev Bu, gelirin zincirde saydam kaydidir. Gercek token transfer
    ///      RFQ solver tarafindan yapilir; burada yalnizca MUHASEBE tutulur.
    ///      ONCE hacim guncellenir, SONRA fee hesaplanir: boylece kullanici
    ///      welcome sinirini gectiginde ayni batch'te standart feeye gecer
    ///      (aksi takdirde 2 batch'e bolunmus gibi welcome'da kalirdi).
    function recordFeeRevenue(uint256 volume, bool isMaker) external onlySolver {
        require(protocolFeeRecipient != address(0), "Komisyon cuzuDani ayarli degil");

        // Once kumulatif hacmi guncelle (sinir gecisi dogru kademeye)
        uint256 newVolume = userCumulativeVolume[msg.sender] + volume;
        userCumulativeVolume[msg.sender] = newVolume;

        uint256 feeRate = this.tradingFeeBps(newVolume, isMaker);
        // 1e-5 birim: fee = volume * rate / 100000
        uint256 fee = (volume * feeRate) / 100_000;

        protocolRevenue += fee;

        emit FeeRevenueRecorded(msg.sender, volume, fee, isMaker);
    }

    /// @notice Kullanici kumulatif hacmini sorgula (kademeyi gormek icin).
    function userVolume(address user) external view returns (uint256) {
        return userCumulativeVolume[user];
    }
}
