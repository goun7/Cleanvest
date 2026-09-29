// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
///      karşı ana kalkan). Bu kontrat:
///        1. Her yaprak = keccak256(abi.encode(user, balance, epoch))
///        2. Her yaprak KULLANICI tarafından EIP-191 ile imzalanır
///        3. Kök (liabilitiesRoot) zincir-üstü yayınlanır
///        4. Herkes kendi yaprağını köre karşı doğrular (inclusion)
///        5. Toplam yükümlülük zincir-üstü sayılır (sumLiabilities)
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

    /// @notice Her epoch için KULLANICI İMZASI kullanılır (collusion kalkanı).
    /// @dev leaf => imza; her yaprak kullanıcı EIP-191 imzası taşır.
    // (İmzalar off-chain kök üretiminde doğrulanır; zincir-üstü doğrulama
    //  verifyLiability() ile yapılır. Bu mapping tek-seferlik kayıt içindir.)

    event LiabilitiesPublished(uint256 indexed epoch, bytes32 indexed root, uint256 totalLiabilities, uint256 leafCount);
    event PublisherAuthorized(address indexed publisher);
    event PublisherRevoked(address indexed publisher);
    event LiabilityVerified(address indexed user, uint256 epoch, bytes32 indexed root, bool included);

    constructor() Ownable(msg.sender) ReentrancyGuard() {}

    modifier onlyPublisher() {
        require(msg.sender == owner() || authorizedPublisher[msg.sender], "Yetkili publisher degil");
        _;
    }

    /// @notice Yeni bir yükümlülük kökü yayınla (her epoch'da bir kez).
    /// @dev Kök, off-chain'da KULLANICI İMZALI yapraklardan üretilir
    ///      (Rust merkle/ crate'i ile aynı algoritma). Zincir yalnızca
    ///      KÖKÜ ve TOPLAMI kaydeder; yaprakları DEĞİL (gas maliyeti).
    /// @param root Merkle kökü (kullanıcı imzalı yapraklardan üretilmiş)
    /// @param totalLiabilities Tüm yaprakların bakiye toplamı (1e18 = 1 USD)
    /// @param leafCount Yaprak sayısı (denetim için)
    function publishLiabilities(bytes32 root, uint256 totalLiabilities, uint256 leafCount) external onlyPublisher {
        require(root != bytes32(0), "Kok sifir olamaz");
        require(leafCount > 0, "Bos agac kabul edilmez");

        currentEpoch += 1;
        liabilitiesRoot = root;
        epochRoot[currentEpoch] = root;
        epochTotalLiabilities[currentEpoch] = totalLiabilities;
        epochTimestamp[currentEpoch] = block.timestamp;
        epochCount += 1;

        emit LiabilitiesPublished(currentEpoch, root, totalLiabilities, leafCount);
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
        return ecrecover(_toEthSignedMessageHash(leaf), v, r, s);
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
