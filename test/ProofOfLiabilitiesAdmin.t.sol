// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/ProofOfLiabilities.sol";

/// @title ProofOfLiabilities Yönetim & Sorgu API Testleri
/// @notice AST taraması (2026-10-07) ile bulunan, hiçbir test tarafından
///         çağrılmayan KRİTİK public/external fonksiyonların kapanışı:
///           - authorizePublisher(address)      (onlyOwner, event, zero-addr)
///           - revokePublisher(address)         (onlyOwner, event, yetki geri al)
///           - epochSummary(uint256)            (view: root/total/timestamp)
///           - coverageRatio(uint256)           (view: bps, sıfır-arz yolu)
///
///         Mevcut ProofOfLiabilities.t.sol DOSYANINA DOKUNULMADı — bu tamamen
///         AYRI bir suite'tir; tüm yardımcılar kendi içinde yeniden üretilmiştir.
///         Dış çağrı YOKTUR: yalnızca sözleşmenin kendi yönetim/view mantığı
///         test edilir (vm.prank ile yetki simülasyonu).
contract ProofOfLiabilitiesAdminTest is Test {
    ProofOfLiabilities public pol;

    /// @dev Test-only deterministik anahtarlar (mainnet değeri YOKTUR).
    Vm.Wallet internal u0;
    Vm.Wallet internal u1;
    Vm.Wallet internal publisherWallet;

    function setUp() public {
        pol = new ProofOfLiabilities();
        u0 = vm.createWallet(uint256(0xC1EA05EA)); // mevcut suite ile aynı seed
        u1 = vm.createWallet(uint256(0x8E571EA5));
        publisherWallet = vm.createWallet(uint256(0x42694745)); // "Bigh" — test-only
    }

    // ============================================================
    // YARDIMCILAR — kontratın birebir Merkle algoritması
    // ============================================================

    function _leaf(address user, uint256 balance, uint256 epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(user, balance, epoch));
    }

    function _sign(uint256 privateKey, bytes32 leaf) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _nextLayer(bytes32[] memory layer) internal pure returns (bytes32[] memory) {
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

    function _rootOf(bytes32[] memory leaves) internal pure returns (bytes32) {
        bytes32[] memory layer = leaves;
        while (layer.length > 1) {
            layer = _nextLayer(layer);
        }
        return layer[0];
    }

    /// @dev 2 imzalı yaprakla (u0, u1) fail-closed yayın yapar (epoch=1).
    function _publishTwo() internal returns (bytes32[] memory leaves, bytes32 root) {
        leaves = new bytes32[](2);
        leaves[0] = _leaf(u0.addr, 1000 ether, 1);
        leaves[1] = _leaf(u1.addr, 2000 ether, 1);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(u0.privateKey, leaves[0]);
        sigs[1] = _sign(u1.privateKey, leaves[1]);

        address[] memory users = new address[](2);
        users[0] = u0.addr;
        users[1] = u1.addr;
        uint256[] memory balances = new uint256[](2);
        balances[0] = 1000 ether;
        balances[1] = 2000 ether;

        root = pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);
    }

    // ============================================================
    // authorizePublisher — onlyOwner, event, zero-adres reddi
    // ============================================================

    /// @notice Owner bir publisher yetkilendirir: mapping true olur ve
    ///         PublisherAuthorized event'i yayılır.
    function testAuthorizePublisherSetsFlagAndEmitsEvent() public {
        assertFalse(pol.authorizedPublisher(publisherWallet.addr), "baslangicta yetkisiz");

        vm.expectEmit(true, false, false, false, address(pol));
        emit ProofOfLiabilities.PublisherAuthorized(publisherWallet.addr);

        pol.authorizePublisher(publisherWallet.addr);

        assertTrue(pol.authorizedPublisher(publisherWallet.addr), "yetki true olmali");
    }

    /// @notice Sıfır adres güvenlik açığıydı — reddedilir (yetki verilemez).
    function testAuthorizePublisherRejectsZeroAddress() public {
        vm.expectRevert("Sifir adres");
        pol.authorizePublisher(address(0));
        assertFalse(pol.authorizedPublisher(address(0)), "sifir adres yetkili olamaz");
    }

    /// @notice Owner OLMAYAN biri publisher yetkilendiremez (yetki yükseltme
    ///         saldırısına karşı onlyOwner koruması).
    function testAuthorizePublisherOnlyOwner() public {
        vm.prank(u0.addr);
        vm.expectRevert();
        pol.authorizePublisher(u1.addr);
        assertFalse(pol.authorizedPublisher(u1.addr), "owner disi yetki veremez");
    }

    // ============================================================
    // revokePublisher — yetkinin geri alınması
    // ============================================================

    /// @notice Owner yetkili publisher'ı iptal eder: mapping false olur ve
    ///         PublisherRevoked event'i yayılır.
    function testRevokePublisherClearsFlagAndEmitsEvent() public {
        pol.authorizePublisher(publisherWallet.addr);
        assertTrue(pol.authorizedPublisher(publisherWallet.addr), "once yetkilendir");

        vm.expectEmit(true, false, false, false, address(pol));
        emit ProofOfLiabilities.PublisherRevoked(publisherWallet.addr);

        pol.revokePublisher(publisherWallet.addr);

        assertFalse(pol.authorizedPublisher(publisherWallet.addr), "yetki false olmali");
    }

    /// @notice Owner OLMAYAN biri publisher iptal edemez (yetki yükseltme /
    ///         kötü niyetli iptal saldırısına karşı onlyOwner).
    function testRevokePublisherOnlyOwner() public {
        pol.authorizePublisher(publisherWallet.addr);
        vm.prank(u0.addr);
        vm.expectRevert();
        pol.revokePublisher(publisherWallet.addr);
        assertTrue(pol.authorizedPublisher(publisherWallet.addr), "owner disi iptal edemez");
    }

    /// @notice Yetkisiz (hiç yetkilendirilmemiş) bir adres iptal edilirse
    ///         hata VERMEZ — idempotent şekilde false kalır (no-op).
    function testRevokeUnpublishedPublisherIsNoOp() public {
        assertFalse(pol.authorizedPublisher(u1.addr), "zaten yetkisiz");
        pol.revokePublisher(u1.addr); // revert OLMAMALI
        assertFalse(pol.authorizedPublisher(u1.addr), "hala yetkisiz");
    }

    // ============================================================
    // onlyPublisher modifier — yetki tabanlı yayın kontrolü
    // ============================================================

    /// @notice Yetkilendirilmiş publisher, owner olmaksızın kök
    ///         yayınlayabilir (onlyPublisher geçerli).
    function testAuthorizedPublisherCanPublishLegacy() public {
        pol.authorizePublisher(publisherWallet.addr);

        bytes32 root = _rootOf(_twoLeaves());
        vm.prank(publisherWallet.addr);
        pol.publishLiabilities(root, 3000 ether, 2);

        assertEq(pol.liabilitiesRoot(), root, "publisher yayinlayabilmeli");
        assertEq(pol.currentEpoch(), 1, "epoch 1");
        assertEq(pol.epochSignatureEnforced(1), false, "legacy yol: imza off-chain");
    }

    /// @notice Yetkisi ALINMIŞ publisher artık yayınlayamaz (onlyPublisher).
    function testRevokedPublisherCannotPublish() public {
        pol.authorizePublisher(publisherWallet.addr);
        pol.revokePublisher(publisherWallet.addr);

        bytes32 root = _rootOf(_twoLeaves());
        vm.prank(publisherWallet.addr);
        vm.expectRevert("Yetkili publisher degil");
        pol.publishLiabilities(root, 3000 ether, 2);

        assertEq(pol.epochCount(), 0, "yayin yapilmamali");
    }

    /// @notice Hiç yetkisi OLMAYAN rastgele adres yayınlayamaz.
    function testUnauthorizedCannotPublish() public {
        bytes32 root = _rootOf(_twoLeaves());
        vm.prank(u0.addr);
        vm.expectRevert("Yetkili publisher degil");
        pol.publishLiabilities(root, 3000 ether, 2);
    }

    /// @notice Owner her zaman yayınlayabilir (yetki ayrıcalığı).
    function testOwnerCanAlwaysPublish() public {
        bytes32 root = _rootOf(_twoLeaves());
        pol.publishLiabilities(root, 3000 ether, 2); // owner = deployer
        assertEq(pol.epochCount(), 1, "owner yayinlayabilmeli");
    }

    // ============================================================
    // epochSummary — kamusal sorgu API'si
    // ============================================================

    /// @notice Yayınlanmış epoch için özet doğru döner: kök, toplam ve
    ///         timestamp birebir eşleşir.
    function testEpochSummaryReturnsPublishedValues() public {
        (bytes32[] memory leaves, bytes32 root) = _publishTwo();
        uint256 ts = block.timestamp;

        (bytes32 sRoot, uint256 sTotal, uint256 sTs) = pol.epochSummary(1);

        assertEq(sRoot, root, "ozet koku dogru");
        assertEq(sTotal, 3000 ether, "ozet toplam dogru (1000+2000)");
        assertEq(sTs, ts, "ozet timestamp dogru");
        assertEq(sRoot, pol.epochRoot(1), "epochRoot ile ayni");
        assertEq(sTotal, pol.epochTotalLiabilities(1), "epochTotalLiabilities ile ayni");
        assertEq(sTs, pol.epochTimestamp(1), "epochTimestamp ile ayni");
        // leaves referansı derlenmemiş kullanımı önlemek için tutarlılık:
        assertEq(leaves.length, 2, "2 yaprak");
    }

    /// @notice Hiç yayınlanmamış epoch için özet sıfır döner (sıfır kök,
    ///         sıfır toplam, sıfır timestamp) — yanıltıcı veri YOK.
    function testEpochSummaryReturnsZerosForUnpublishedEpoch() public {
        (bytes32 sRoot, uint256 sTotal, uint256 sTs) = pol.epochSummary(42);
        assertEq(sRoot, bytes32(0), "yayinlanmamis epoch: kok sifir");
        assertEq(sTotal, 0, "yayinlanmamis epoch: toplam sifir");
        assertEq(sTs, 0, "yayinlanmamis epoch: timestamp sifir");
    }

    /// @notice Birden fazla epoch yayınında her epoch'un özeti KENDİ
    ///         değerlerini döner (epoch'lar arası karışma yok).
    function testEpochSummaryIsolatesMultipleEpochs() public {
        (, bytes32 root1) = _publishTwo(); // epoch 1: total 3000

        // epoch 2: legacy yol, farklı kök ve toplam
        bytes32[] memory l2 = new bytes32[](1);
        l2[0] = _leaf(u0.addr, 500 ether, 2);
        bytes32 root2 = _rootOf(l2);
        pol.publishLiabilities(root2, 500 ether, 1); // epoch 2

        (bytes32 r1, uint256 t1,) = pol.epochSummary(1);
        (bytes32 r2, uint256 t2,) = pol.epochSummary(2);

        assertEq(r1, root1, "epoch 1 koku");
        assertEq(t1, 3000 ether, "epoch 1 toplam");
        assertEq(r2, root2, "epoch 2 koku");
        assertEq(t2, 500 ether, "epoch 2 toplam");
        assertTrue(r1 != r2, "kokler farkli olmali");
        assertEq(pol.currentEpoch(), 2, "mevcut epoch 2");
        assertEq(pol.epochCount(), 2, "2 epoch yayinlandi");
    }

    // ============================================================
    // coverageRatio — arz/kapsama oranı (bps)
    // ============================================================

    /// @notice cUsdTotalSupply = 0 ise belirsizlik: max(uint256) döner
    ///         (bölme hatası YOK, güvenli sentinel).
    function testCoverageRatioZeroSupplyReturnsMax() public {
        _publishTwo(); // epoch 1: total liabilities 3000
        assertEq(pol.coverageRatio(0), type(uint256).max, "sifir arizda max donmeli");
    }

    /// @notice Toplam yükümlülük = arz → bps = 10000 (%100 tam kapsama).
    function testCoverageRatioFullCoverage() public {
        _publishTwo(); // total liabilities 3000
        assertEq(pol.coverageRatio(3000 ether), 10_000, "100% kapsama = 10000 bps");
    }

    /// @notice Toplam yükümlülük > arz → bps > 10000 (aşırı taahhüt).
    function testCoverageRatioOverCoverage() public {
        _publishTwo(); // total liabilities 3000
        // 3000 / 1500 * 10000 = 20000 bps (%200)
        assertEq(pol.coverageRatio(1500 ether), 20_000, "200% kapsama = 20000 bps");
    }

    /// @notice Toplam yükümlülük < arz → bps < 10000 (eksik kapsama).
    function testCoverageRatioUnderCoverage() public {
        _publishTwo(); // total liabilities 3000
        // 3000 / 6000 * 10000 = 5000 bps (%50)
        assertEq(pol.coverageRatio(6000 ether), 5_000, "50% kapsama = 5000 bps");
    }

    /// @notice Hiç yayınlanmamış kontratta mevcut epoch toplamı 0'dır →
    ///         sıfır olmayan herhangi bir arz için bps = 0 döner
    ///         (0 * 10000 / supply = 0); sıfır arzda yine max.
    function testCoverageRatioBeforeAnyPublish() public {
        assertEq(pol.coverageRatio(1000 ether), 0, "yayin yokken bps 0");
        assertEq(pol.coverageRatio(0), type(uint256).max, "sifir arizda max");
    }

    /// @notice coverageRatio EN SON epoch'un yükümlülüğünü kullanır
    ///         (currentEpoch), eski epoch'ların değil.
    function testCoverageRatioUsesLatestEpoch() public {
        _publishTwo(); // epoch 1: total 3000
        // epoch 2: total 9000 (3x)
        bytes32[] memory l2 = new bytes32[](1);
        l2[0] = _leaf(u0.addr, 9000 ether, 2);
        pol.publishLiabilities(_rootOf(l2), 9000 ether, 1);

        // 9000 / 3000 * 10000 = 30000 bps (en son epoch bazlı)
        assertEq(pol.coverageRatio(3000 ether), 30_000, "en son epoch kullanilmali");
    }

    // ============================================================
    // yardımcı: 2 yaprak (epoch=1) — legacy yayın testleri için
    // ============================================================

    function _twoLeaves() internal view returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = _leaf(u0.addr, 1000 ether, 1);
        leaves[1] = _leaf(u1.addr, 2000 ether, 1);
        return leaves;
    }
}
