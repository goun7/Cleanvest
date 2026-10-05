// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice EIP-2: imzanin s degeri HIGH-s (malleable). (r,s) ile (r,n-s) ayni
///         adresi geri kazanir — bir imzadan ikinci gosterim (representation)
///         uretilebilir. Bu, replay saldirisi icin kullanilabilir.
/// @dev DAR gorev (2026-09-30) — durust sinir #4'UN kapanisi:
///      "ECDSA imza malleability (low-s/EIP-2) kontrolu YOKTUR" artik
///      GECERSIZDIR. Hem legacy EIP-191 (_recoverSigner) hem EIP-712
///      (_recoverSignerRaw) yollarinda uygulanir — ACIK REVERT.
error InvalidSignatureS();

/// @title ProofOfLiabilities — Merkle Tabanlı Yükümlülük Kanıtı (PoL)
/// @author Cleanvest
/// @notice README dürüst sınır #1'İN KAPANMASI: "PoR/PoL DEĞİL" ifadesi
///         artık DARALTILMIŞTIR. $cUSD'nin arkasındaki YÜKÜMLÜLÜKLER
///         (liabilities) artık imzalı Merkle yapraklarıyla zincir-üstü
///         taahhüt edilir ve HER KULLANICI kendi bakiyesini bağımsız
///         doğrulayabilir.
///
/// @dev AKADEMİK TEMEL — bu, AsiaCCS 2026 makalesinin DOĞRUDAN uygulamasıdır:
///      "Mitigating Collusion in Proofs of Liabilities" (AsiaCCS'26)
///      [`docs/arastirma/05`](../docs/arastirma/05_merkle_kanitlari_finansal_uygulamalar_2025_2026.md)
///      Makale, commit edilen vektörün yalnızca KULLANICILARIN İMZALADIĞI
///      değerleri içermesini bir GEREKLİLİK olarak öne sürer (collusion'a
///      karşı ana kalkan). Bu kontrat İKİ yayın yolu sunar:
///        A) publishLiabilitiesFromSignedLeaves() — FAIL-CLOSED: her yaprağın
///           EIP-191 imzası ZİNCİRDE doğrulanır ve KÖK imzalı yapraklardan
///           ZİNCİRDE türetilir. Operatör kökü seçemez; imzasız yaprak
///           uyduramaz (tek geçersiz imza tüm yayını revert eder).
///           AsiaCCS'26 gereksinimi ZİNCİR-ÜSTÜNDE KANITLANIR.
///        B) publishLiabilities() — LEGACY/GAZ-VERİMLİ: yalnızca kök + toplam
///           yayınlanır; imza doğrulaması OFF-CHAIN varsayılır. Bu yol
///           gereksinimi zincir-üstünde KANITLAMAZ (epochSignatureEnforced=false).
///        Ayrıca (DAR, 2026-09-29) DOMAIN-AWARE variantlar:
///        A2) publishLiabilitiesFromSignedLeavesWithDomain() — A'nın aynısı,
///            fakat yaprak imzaları EIP-712 domain özeti (name, version,
///            chainId, verifyingContract) üzerinedir — ALAN-AYRIMI: aynı imza
///            başka kontratta/zincirde GEÇERLİ DEĞİLDİR. Doğrulama:
///            verifyLiabilityWithDomain(). Legacy EIP-191 yolu (A + verifyLiability)
///            geriye dönük uyum için olduğu gibi KALDI.
///      Her iki yolda da:
///        1. Her yaprak = keccak256(abi.encode(user, balance, epoch))
///        2. Yaprak KULLANICI tarafından EIP-191 ile imzalanır
///        3. Kök (liabilitiesRoot) zincir-üstü yayınlanır
///        4. Herkes kendi yaprağını köre karşı doğrular (verifyLiability)
///        5. Toplam yükümlülük zincir-üstü sayılır (epochTotalLiabilities)
///
///      DÜRÜST SINIR (NASIL OKUNMALI): bu bir **kayıt-muhasebe**
///      taahhüdüdür — rezervlerin VARLIĞINI kanıtlamaz (banka-DDO
///      entegrasyonu gerektirir), yalnızca operatörün taahhüt ettiği
///      yükümlülük LİSTESİNİN kullanıcılarla UYUŞTUĞUNU kanıtlar.
///      Yani: "operatör kullanıcıları kandıramaz" kanıtlanır;
///      "rezervler gerçekte var" kanıtlanmaz (off-chain kanıt gerekir).
///      Bu ayrım AsiaCCS makalesinin kendi sınırıdır.
contract ProofOfLiabilities is Ownable, ReentrancyGuard {
    /// @notice Yükümlülük yaprağı: her kullanıcı için bir kayıt.
    /// @dev leaf = keccak256(abi.encode(user, balance, epoch))
    struct LiabilityLeaf {
        address user; // kullanıcı adresi
        uint256 balance; // 1e18 = 1 USD (cUSD cinsinden)
        uint256 epoch; // dönem (her PoL güncellemesi = yeni epoch)
    }

    /// @notice Mevcut (en son) yayınlanmış yükümlülük kökü.
    bytes32 public liabilitiesRoot;

    /// @notice En son epoch (her güncellemede artar).
    uint256 public currentEpoch;

    /// @notice Epoch => toplam yükümlülük (tüm yaprakların toplamı).
    mapping(uint256 => uint256) public epochTotalLiabilities;

    /// @notice Epoch => kök (geçmiş tüm kökler sorgulanabilir).
    mapping(uint256 => bytes32) public epochRoot;

    /// @notice Epoch => yayınlanma timestamp'i.
    mapping(uint256 => uint256) public epochTimestamp;

    /// @notice Operatör => yetkili mi (kök yayınlayabilir).
    mapping(address => bool) public authorizedPublisher;

    /// @notice Toplam yayınlanmış epoch sayısı.
    uint256 public epochCount;

    /// @notice Epoch => yaprak sayısı (denetim için).
    mapping(uint256 => uint256) public epochLeafCount;

    /// @notice Epoch => kök, KULLANICI İMZALI yapraklardan ZİNCİR-ÜSTÜNDE
    ///         türetildi mi? (AsiaCCS'26 gereksiniminin zincir-üstü kanıtı)
    /// @dev true  = publishLiabilitiesFromSignedLeaves ile yayınlandı: her
    ///              yaprağın EIP-191 imzası ZİNCİRDE doğrulandı, tek geçersiz
    ///              imza tüm yayını revert etti (fail-closed).
    ///      false = publishLiabilities ile HAM kök yayınlandı: imza
    ///              doğrulaması OFF-CHAIN varsayılır; bu yol AsiaCCS'26
    ///              gereksinimini zincir-üstünde KANITLAMAZ.
    mapping(uint256 => bool) public epochSignatureEnforced;

    event LiabilitiesPublished(
        uint256 indexed epoch, bytes32 indexed root, uint256 totalLiabilities, uint256 leafCount
    );
    event PublisherAuthorized(address indexed publisher);
    event PublisherRevoked(address indexed publisher);
    event LiabilityVerified(
        address indexed user, uint256 epoch, bytes32 indexed root, bool included
    );

    // ============================================================
    // EIP-712 ALAN-AYRIMI (DOMAIN SEPARATION) — DÜRÜST SINIR KAPANIYOR
    // (DAR görev, 2026-09-29): README'nin "imzanın alan-ayrımı (domain
    // separation) YOKTUR" sınırı. İmza artık EIP-712 ile
    // (name, version, chainId, verifyingContract) alanına BAĞLIDIR:
    // aynı imza başka bir kontratta (cross-contract) veya başka bir
    // zincirde (cross-chain) GEÇERLİ DEĞİLDİR — domain separator
    // farklı → özet farklı → ecrecover farklı adres → REVERT.
    // LEGACY YOL (verifyLiability + publishLiabilitiesFromSignedLeaves,
    // EIP-191) OLDUĞU GİBİ KALDI — geriye dönük uyum (R9-2 tarzı).
    // ============================================================

    /// @notice EIP-712 domain adı — imzayı BU kontratın adına bağlar.
    string public constant EIP712_NAME = "Cleanvest-ProofOfLiabilities";

    /// @notice EIP-712 domain sürümü — imza şeması değişirse artırılır.
    string public constant EIP712_VERSION = "1";

    /// @dev EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev LiabilityLeaf(address user,uint256 balance,uint256 epoch)
    ///      — alan sıralaması legacy Merkle yaprağı ile BİREBİR AYNI;
    ///      böylece ağaç algoritması ve kök hesabı DEĞİŞMEZ.
    bytes32 private constant LIABILITY_LEAF_TYPEHASH =
        keccak256("LiabilityLeaf(address user,uint256 balance,uint256 epoch)");

    /// @notice secp256k1 eğri sırası n — EIP-2 low-s eşiğinin kaynağı.
    /// @dev EIP-2: s > n/2 olan imzalar MALLEABLE'dir. n tek sayı olduğundan
    ///      n/2 (floor) == (n-1)/2 ve hiçbir tamsayı s tam olarak n/2 olamaz —
    ///      "s <= n/2" koşulu EIP-2 spec ile BİREBİR ÖRTÜŞÜR. Bu sabit hem
    ///      legacy (_recoverSigner) hem EIP-712 (_recoverSignerRaw) yollarını
    ///      koruyan InvalidSignatureS kontrolünde kullanılır (durust sınır #4).
    uint256 internal constant SECP256K1_N =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    constructor() Ownable(msg.sender) ReentrancyGuard() {}

    modifier onlyPublisher() {
        require(msg.sender == owner() || authorizedPublisher[msg.sender], "Yetkili publisher degil");
        _;
    }

    /// @notice Yeni bir yükümlülük kökü yayınla (her epoch'da bir kez).
    /// @dev LEGACY / GAZ-VERİMLİ YOL. Kök, off-chain'da KULLANICI İMZALI
    ///      yapraklardan üretilir (Rust merkle/ crate'i ile aynı algoritma);
    ///      zincir yalnızca KÖKÜ ve TOPLAMI kaydeder, yaprakları DEĞİL.
    ///
    ///      DÜRÜST SINIR: bu yol AsiaCCS'26 gereksinimini ZİNCİR-ÜSTÜNDE
    ///      KANITLAMAZ — imza doğrulaması OFF-CHAIN yapılır varsayılır.
    ///      `epochSignatureEnforced[epoch] = false` olarak işaretlenir, böylece
    ///      denetçi bu epoch'un kökünün ancak off-chain imza denetimiyle
    ///      güvenilir olduğunu ayırt edebilir. On-chain fail-closed garanti
    ///      için publishLiabilitiesFromSignedLeaves() kullanın.
    /// @param root Merkle kökü (kullanıcı imzalı yapraklardan üretilmiş)
    /// @param totalLiabilities Tüm yaprakların bakiye toplamı (1e18 = 1 USD)
    /// @param leafCount Yaprak sayısı (denetim için)
    function publishLiabilities(bytes32 root, uint256 totalLiabilities, uint256 leafCount)
        external
        onlyPublisher
    {
        require(root != bytes32(0), "Kok sifir olamaz");
        require(leafCount > 0, "Bos agac kabul edilmez");

        currentEpoch += 1;
        liabilitiesRoot = root;
        epochRoot[currentEpoch] = root;
        epochTotalLiabilities[currentEpoch] = totalLiabilities;
        epochTimestamp[currentEpoch] = block.timestamp;
        epochLeafCount[currentEpoch] = leafCount;
        // HAM kök yolu: imzalar off-chain doğrulanmış varsayılır.
        epochSignatureEnforced[currentEpoch] = false;
        epochCount += 1;

        emit LiabilitiesPublished(currentEpoch, root, totalLiabilities, leafCount);
    }

    /// @notice FAIL-CLOSED kök yayınla: kök, KULLANICI İMZALI yapraklardan
    ///         ZİNCİR-ÜSTÜNDE türetilir. Bu, AsiaCCS'26 makalesinin ana
    ///         gereksiniminin ("commit edilen vektör yalnızca kullanıcıların
    ///         imzaladığı değerleri içermelidir") ZİNCİR-ÜSTÜ KANITIDIR.
    /// @dev Operatör KÖKÜ SEÇEMEZ — kök, imzası doğrulanmış yapraklardan
    ///      hesaplanır. Her yaprak için EIP-191 imzası doğrulanır; TEK bir
    ///      geçersiz/eksik imza TÜM yayın işlemini REVERT EDER. Dolayısıyla
    ///      operatör imzalamadığı bir kullanıcı UYDURAMAZ (fail-closed).
    ///
    ///      Epoch, zincirde belirlenir (currentEpoch + 1); kullanıcılar bu
    ///      epoch numarası üzerinden imzalar (operator imzaları toplarken
    ///      bir sonraki epoch'u bilir).
    /// @param users Kullanıcı adresleri
    /// @param balances Bakiyeler, 1e18 = 1 USD (users ile sıralı)
    /// @param sigs EIP-191 imzaları: keccak256(abi.encode(user, balance, epoch))
    ///             özeti üzerinde, users/balances ile sıralı
    /// @return root Yayımlanan Merkle kökü (imzalı yapraklardan türetilmiş)
    function publishLiabilitiesFromSignedLeaves(
        address[] calldata users,
        uint256[] calldata balances,
        bytes[] calldata sigs
    ) external onlyPublisher returns (bytes32 root) {
        // LEGACY YOL: EIP-191 imzası (alan-ayrımı YOK) — geriye dönük uyum.
        return _publishFromSignedLeaves(users, balances, sigs, false);
    }

    /// @notice FAIL-CLOSED + DOMAIN-AWARE kök yayın: tıpkı
    ///         publishLiabilitiesFromSignedLeaves() gibidir, ancak her yaprak
    ///         imzası EIP-712 domain özeti (name, version, chainId,
    ///         verifyingContract) üzerinedir.
    /// @dev DÜRÜST SINIR (alan-ayrımı) KAPANIYOR: aynı imza başka bir
    ///      kontratta veya başka bir zincirde KULLANILAMAZ — domain
    ///      separator zincirde belirlenir (block.chainid + address(this)),
    ///      saldıran değiştiremez. Ağaç/kök algoritması legacy ile BİREBİR
    ///      AYNI (yaprak sıralaması değişmedi).
    /// @param users Kullanıcı adresleri
    /// @param balances Bakiyeler, 1e18 = 1 USD (users ile sıralı)
    /// @param sigs EIP-712 imzaları: liabilityDomainDigest(user, balance, epoch)
    ///             özeti üzerinde, users/balances ile sıralı
    /// @return root Yayımlanan Merkle kökü (imzalı yapraklardan türetilmiş)
    function publishLiabilitiesFromSignedLeavesWithDomain(
        address[] calldata users,
        uint256[] calldata balances,
        bytes[] calldata sigs
    ) external onlyPublisher returns (bytes32 root) {
        return _publishFromSignedLeaves(users, balances, sigs, true);
    }

    /// @dev İmzalı yapraklar'dan fail-closed kök türeten PAYLAŞILAN çekirdek.
    ///      domainAware=false → EIP-191 (legacy); true → EIP-712 domain özeti.
    ///      Tek fark imza doğrulamasının özetidir; ağaç ve kök AYNIdır.
    function _publishFromSignedLeaves(
        address[] calldata users,
        uint256[] calldata balances,
        bytes[] calldata sigs,
        bool domainAware
    ) internal returns (bytes32 root) {
        require(users.length > 0, "Bos agac kabul edilmez");
        require(
            users.length == balances.length && users.length == sigs.length,
            "Dizi uzunluklari uyusmali"
        );

        uint256 epoch = currentEpoch + 1;
        uint256 total;
        bytes32[] memory leaves = new bytes32[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Sifir kullanici reddedilir");
            // ASIA CCS'26 GEREKSİNİMİ (fail-closed): her yaprak KULLANICI
            // tarafından imzalanmış OLMALIDIR. İmza yoksa revert -> operatör
            // yaprak UYDURAMAZ, kökü de seçemez.
            bytes32 leaf = keccak256(abi.encode(users[i], balances[i], epoch));
            // ALAN-AYRIMI: domainAware ise imza EIP-712 domain özeti üzerinedir
            // (cross-contract/cross-chain replay yapısal olarak reddedilir).
            bytes32 digest = domainAware
                ? liabilityDomainDigest(users[i], balances[i], epoch)
                : _toEthSignedMessageHash(leaf);
            require(
                _recoverSignerRaw(digest, sigs[i]) == users[i],
                "Kullanici imzasi gecersiz (yaprak imzalanmamis)"
            );
            leaves[i] = leaf;
            total += balances[i];
        }

        // Kök, DOĞRULANMIŞ yapraklardan zincir-üstünde türetilir.
        root = _computeRootFromLeaves(leaves);

        currentEpoch = epoch;
        liabilitiesRoot = root;
        epochRoot[epoch] = root;
        epochTotalLiabilities[epoch] = total;
        epochTimestamp[epoch] = block.timestamp;
        epochLeafCount[epoch] = users.length;
        epochSignatureEnforced[epoch] = true;
        epochCount += 1;

        emit LiabilitiesPublished(epoch, root, total, users.length);
    }

    /// @notice Bir kullanıcının yükümlülüğünü (bakiyesini) köre karşı doğrular.
    /// @dev Bu, bağımsız doğrulamanın zincir-üstü kanıtıdır. Kullanıcı
    ///      kendi yaprak imzasını + Merkle yolunu sunar; zincir ikisini de
    ///      doğrular. ASIA CCS'26 gerekliliği: imza, operatörün yaprak
    ///      doldurmasını engeller.
    /// @param user Kullanıcı adresi
    /// @param balance İddia edilen bakiye (1e18 = 1 USD)
    /// @param epoch Doğrulanan dönem
    /// @param sig Kullanıcının EIP-191 imzası (yaprak hash'i üzerinde)
    /// @param proof Merkle sibling yolu (33 bayt/seviye)
    /// @return included Yaprak kökte mevcut ve imza geçerli
    function verifyLiability(
        address user,
        uint256 balance,
        uint256 epoch,
        bytes memory sig,
        bytes memory proof
    ) external nonReentrant returns (bool included) {
        bytes32 root = epochRoot[epoch];
        require(root != bytes32(0), "Epoch yayinlanmamis");

        // 1. Yaprak hash'i (CleanvestSettlement ile AYNI paketleme)
        bytes32 leaf = keccak256(abi.encode(user, balance, epoch));

        // 2. Kullanıcı imzası (EIP-191) — operatör yaprak dolduramaz
        require(_recoverSigner(leaf, sig) == user, "Imza gecersiz (kullanici imzalamamis)");

        // 3. Merkle inclusion
        bool ok = _verifyMerkleProof(leaf, proof, root);

        emit LiabilityVerified(user, epoch, root, ok);
        return ok;
    }

    // ============================================================
    // EIP-712 ALAN-AYRIMI — domain-aware doğrulama (2026-09-29)
    // ============================================================

    /// @notice EIP-712 domain separator: (name, version, chainId, verifyingContract).
    /// @dev Bu, imzayı BU kontrata ve BU zincire bağlar — cross-contract ve
    ///      cross-chain replay'i yapısal olarak engeller. chainId ve
    ///      verifyingContract zincirde belirlenir; saldırgan DEĞİŞTİREMEZ.
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(EIP712_NAME)),
                keccak256(bytes(EIP712_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice LiabilityLeaf için EIP-712 struct hash'i.
    /// @dev keccak256(abi.encode(LIABILITY_LEAF_TYPEHASH, user, balance, epoch)).
    ///      Legacy Merkle yaprağı ile AYNI alan sıralaması — yalnızca başlık
    ///      (typeHash) eklenir; ağaç algoritması ve kök hesabı DEĞİŞMEZ.
    function liabilityLeafStructHash(address user, uint256 balance, uint256 epoch)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(LIABILITY_LEAF_TYPEHASH, user, balance, epoch));
    }

    /// @notice LiabilityLeaf için tam EIP-712 özeti — imza bunun üzerinedir.
    /// @dev keccak256("\x19\x01" || domainSeparator || structHash).
    ///      Off-chain imzalayan (cüzdan / Rust crate) AYNI baytları üretmelidir.
    function liabilityDomainDigest(address user, uint256 balance, uint256 epoch)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", domainSeparator(), liabilityLeafStructHash(user, balance, epoch)
            )
        );
    }

    /// @notice DOMAIN-AWARE liability doğrulama (EIP-712).
    /// @dev İmza artık domain özeti üzerinedir: aynı imza başka bir
    ///      verifyingContract (cross-contract) veya başka bir chainId
    ///      (cross-chain) ile GEÇERLİ DEĞİLDİR — domain separator farklı
    ///      → özet farklı → ecrecover farklı adres → REVERT (fail-closed).
    ///      Merkle yaprağı ve kök algoritması legacy ile BİREBİR AYNI.
    ///      LEGACY YOL: verifyLiability() (EIP-191) geriye dönük uyum için
    ///      hâlâ mevcuttur — eski imzalar çalışmaya devam eder.
    /// @param user Kullanıcı adresi
    /// @param balance İddia edilen bakiye (1e18 = 1 USD)
    /// @param epoch Doğrulanan dönem
    /// @param sig Kullanıcının EIP-712 imzası (domain özeti üzerinde)
    /// @param proof Merkle sibling yolu (33 bayt/seviye)
    /// @return included Yaprak kökte mevcut ve domain imzası geçerli
    function verifyLiabilityWithDomain(
        address user,
        uint256 balance,
        uint256 epoch,
        bytes memory sig,
        bytes memory proof
    ) external nonReentrant returns (bool included) {
        bytes32 root = epochRoot[epoch];
        require(root != bytes32(0), "Epoch yayinlanmamis");

        // 1. Merkle yaprağı (legacy ile AYNI — ağaç/kök değişmez)
        bytes32 leaf = keccak256(abi.encode(user, balance, epoch));

        // 2. EIP-712 domain imzası — alan-ayrımı (cross-contract/cross-chain red)
        bytes32 digest = liabilityDomainDigest(user, balance, epoch);
        require(_recoverSignerRaw(digest, sig) == user, "EIP-712 domain imzasi gecersiz");

        // 3. Merkle inclusion
        bool ok = _verifyMerkleProof(leaf, proof, root);

        emit LiabilityVerified(user, epoch, root, ok);
        return ok;
    }

    /// @notice Bir epoch'un özetini kamusal olarak sorgula (ücretsiz API).
    function epochSummary(uint256 epoch)
        external
        view
        returns (bytes32 root, uint256 totalLiabilities, uint256 publishedAt)
    {
        return (epochRoot[epoch], epochTotalLiabilities[epoch], epochTimestamp[epoch]);
    }

    /// @notice En son epoch'un kapsama oranı (toplam yükümlülük / mevcut arz).
    /// @dev DÜRÜST: bu oran > %100 ise EKSİK rezerv anlamına GELMEZ —
    ///      yalnızca taahhüt edilen yükümlülüklerin ARZ ile karşılaştırmasıdır.
    ///      Arz, CleanUSD.totalSupply() ile dışarıdan alınır.
    function coverageRatio(uint256 cUsdTotalSupply) external view returns (uint256 bps) {
        if (cUsdTotalSupply == 0) return type(uint256).max;
        return (epochTotalLiabilities[currentEpoch] * 10_000) / cUsdTotalSupply;
    }

    // ============================================================
    // YÖNETİM
    // ============================================================

    function authorizePublisher(address publisher) external onlyOwner {
        require(publisher != address(0), "Sifir adres");
        authorizedPublisher[publisher] = true;
        emit PublisherAuthorized(publisher);
    }

    function revokePublisher(address publisher) external onlyOwner {
        authorizedPublisher[publisher] = false;
        emit PublisherRevoked(publisher);
    }

    // ============================================================
    // MERKLE DOĞRULAMA — CleanvestSettlement ile BİREBİR algoritma
    // ============================================================

    /// @dev EIP-191 imza özeti (CleanvestSettlement.toEthSignedMessageHash ile aynı).
    function _toEthSignedMessageHash(bytes32 hash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /// @dev İmzadan imzalayan adresi geri kazanır.
    ///      EIP-2 (DAR 2026-09-30, durust sınır #4): high-s imzalar MALLEABLE —
    ///      (r,s) ile (r,n-s,v') ayni adresi geri kazanir. s > n/2 ise ACIK
    ///      REVERT (InvalidSignatureS) — malleable gosterim kabul EDİLMEZ.
    function _recoverSigner(bytes32 leaf, bytes memory sig) private pure returns (address) {
        require(sig.length == 65, "Imza 65 bayt olmali");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        // EIP-2: low-s ZORUNLU — legacy yol da malleability'e kapatildi.
        if (uint256(s) > SECP256K1_N / 2) revert InvalidSignatureS();
        return ecrecover(_toEthSignedMessageHash(leaf), v, r, s);
    }

    /// @dev EIP-712 özeti (zaten "\x19\x01" önekini içerir) üzerinden imzalayan
    ///      adresi geri kazanır — EIP-191 sarmalama YAPILMAZ. Legacy
    ///      _recoverSigner'dan tek farkı önetin dışarıda hazır gelmesidir.
    ///      EIP-2 (DAR 2026-09-30, durust sınır #4): high-s imzalar MALLEABLE —
    ///      s > n/2 ise ACIK REVERT (InvalidSignatureS) ile reddedilir.
    function _recoverSignerRaw(bytes32 digest, bytes memory sig) private pure returns (address) {
        require(sig.length == 65, "Imza 65 bayt olmali");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        // EIP-2: low-s ZORUNLU — domain-aware yol da malleability'e kapatildi.
        if (uint256(s) > SECP256K1_N / 2) revert InvalidSignatureS();
        return ecrecover(digest, v, r, s);
    }

    /// @dev Çift-yapraklı Merkle doğrulama (CleanvestSettlement ile birebir).
    function _verifyMerkleProof(bytes32 leaf, bytes memory proof, bytes32 root)
        private
        pure
        returns (bool)
    {
        if (proof.length % 33 != 0) return false;

        bytes32 acc = leaf;
        for (uint256 i = 0; i < proof.length; i += 33) {
            bytes32 sibling;
            assembly {
                let ptr := add(add(proof, 32), i)
                sibling := mload(ptr)
            }
            bool isRight = (proof[i + 32] & 0x01) == 0x01;
            if (isRight) {
                acc = keccak256(abi.encode(acc, sibling));
            } else {
                acc = keccak256(abi.encode(sibling, acc));
            }
        }
        return acc == root;
    }

    /// @notice Test/üretim için: yaprak listesinden kök üretir (referans).
    /// @dev CleanvestSettlement.computeRoot ile AYNI algoritma — tek bir
    ///      test ağacını hem PoL hem de emir taahhüdü için kullanılabilir.
    function computeLiabilitiesRoot(bytes32[] memory leaves) external pure returns (bytes32) {
        return _computeRootFromLeaves(leaves);
    }

    /// @dev Çift-yapraklı Merkle kökü (tek kalan kendisiyle eşleşir).
    ///      publishLiabilitiesFromSignedLeaves() ile AYNI algoritma —
    ///      doğrulanmış yapraklardan türetilen kök birebir karşılaştırılabilir.
    function _computeRootFromLeaves(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "Bos agac koku tanimsiz");
        bytes32[] memory layer = leaves;
        while (layer.length > 1) {
            layer = _buildLayer(layer);
        }
        return layer[0];
    }

    function _buildLayer(bytes32[] memory layer) private pure returns (bytes32[] memory) {
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
}
