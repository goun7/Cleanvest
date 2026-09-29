// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/ProofOfLiabilities.sol";

/// @title ProofOfLiabilities Testleri — "PoL GERÇEK" (DAR parça)
/// @notice AsiaCCS'26 gereksiniminin ZİNCİR-ÜSTÜ kanıtı:
///         "commit edilen vektör yalnızca kullanıcıların imzaladığı
///          değerleri içermelidir" (collusion'a karşı ana kalkan).
///
///         Bu testler publishLiabilitiesFromSignedLeaves()'in FAIL-CLOSED
///         olduğunu doğrular: operatör imzasız yaprak UYDURAMAZ ve kökü
///         KENDİSİ SEÇEMEZ — kök, zincir-üstünde imzalı yapraklardan türetilir.
///
///         Anahtarlar vm.createWallet(seed) ile test-only, DETERMİNİSTİK
///         olarak üretilir — PRIVATE_KEY DEĞİL, mainnet değeri YOKTUR.
contract ProofOfLiabilitiesTest is Test {
    ProofOfLiabilities public pol;

    /// @dev 4 test kullanıcısı. createWallet(seed) deterministiktir.
    Vm.Wallet internal u0;
    Vm.Wallet internal u1;
    Vm.Wallet internal u2;
    Vm.Wallet internal u3;

    function setUp() public {
        pol = new ProofOfLiabilities();
        u0 = vm.createWallet(uint256(0xC1EA05EA)); // "CLEA" — test-only seed
        u1 = vm.createWallet(uint256(0x8E571EA5)); // "NESI" — test-only seed
        u2 = vm.createWallet(uint256(0x7553CC35)); // "VEST" — test-only seed
        u3 = vm.createWallet(uint256(0x011A6005)); // test-only seed
    }

    // ============================================================
    // YARDIMCILAR — ProofOfLiabilities'in birebir Merkle algoritması
    // ============================================================

    /// @dev leaf = keccak256(abi.encode(user, balance, epoch)) — kontrat ile aynı.
    function _leaf(address user, uint256 balance, uint256 epoch)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(user, balance, epoch));
    }

    /// @dev EIP-191 imzası (r,s,v) — kontratın _recoverSigner ile aynı şema.
    function _sign(uint256 privateKey, bytes32 leaf) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Çift-yapraklı katman — kontratın _buildLayer ile birebir.
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

    /// @dev 33 bayt/seviye sibling+konum kanıtı — kontratın
    ///      _verifyMerkleProof ile birebir (bit=1 → sibling sağda).
    function _buildProof(bytes32[] memory leaves, uint256 index)
        internal
        pure
        returns (bytes memory proof)
    {
        bytes32[] memory layer = leaves;
        uint256 idx = index;
        while (layer.length > 1) {
            uint256 n = layer.length;
            bytes32 sibling;
            uint8 posBit;
            if (idx % 2 == 0) {
                // Soldayız; sibling sağda (veya tek-kaldıysa kendimiz).
                sibling = (idx + 1 < n) ? layer[idx + 1] : layer[idx];
                posBit = 1;
            } else {
                // Sağdayız; sibling solda.
                sibling = layer[idx - 1];
                posBit = 0;
            }
            proof = abi.encodePacked(proof, sibling, posBit);
            layer = _nextLayer(layer);
            idx = idx / 2;
        }
    }

    /// @dev 4 kullanıcının imzalı yapraklarını ve kökünü kurar (epoch=1).
    function _fourSignedLeaves()
        internal
        view
        returns (bytes32[] memory leaves, bytes32 root)
    {
        leaves = new bytes32[](4);
        leaves[0] = _leaf(u0.addr, 1000 ether, 1);
        leaves[1] = _leaf(u1.addr, 2000 ether, 1);
        leaves[2] = _leaf(u2.addr, 3000 ether, 1);
        leaves[3] = _leaf(u3.addr, 4000 ether, 1);
        root = pol.computeLiabilitiesRoot(leaves);
    }

    function _sigsForFour() internal view returns (bytes[] memory sigs) {
        sigs = new bytes[](4);
        sigs[0] = _sign(u0.privateKey, _leaf(u0.addr, 1000 ether, 1));
        sigs[1] = _sign(u1.privateKey, _leaf(u1.addr, 2000 ether, 1));
        sigs[2] = _sign(u2.privateKey, _leaf(u2.addr, 3000 ether, 1));
        sigs[3] = _sign(u3.privateKey, _leaf(u3.addr, 4000 ether, 1));
    }

    // ============================================================
    // 1) MUTLU YOL — N kullanıcı imzalar, kök doğru, herkes doğrular
    // ============================================================

    /// @notice 4 kullanıcı imzalar → kök imzalı yapraklardan türetilir,
    ///         bağımsız hesaplanan kökle BİREBİR eşleşir ve her kullanıcının
    ///         verifyLiability'u true döner.
    function testSignedLeavesProduceCorrectRootAndAllVerify() public {
        (bytes32[] memory leaves, bytes32 expectedRoot) = _fourSignedLeaves();
        bytes[] memory sigs = _sigsForFour();
        address[] memory users = new address[](4);
        users[0] = u0.addr;
        users[1] = u1.addr;
        users[2] = u2.addr;
        users[3] = u3.addr;
        uint256[] memory balances = new uint256[](4);
        balances[0] = 1000 ether;
        balances[1] = 2000 ether;
        balances[2] = 3000 ether;
        balances[3] = 4000 ether;

        bytes32 published = pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);

        // Kök, imzalı yapraklardan ZİNCİR-ÜSTÜNDE türetildi — operatör
        // seçmedi, kontrat hesapladı.
        assertEq(published, expectedRoot, "Kok imzali yapraklardan turetilmeli");
        assertEq(pol.liabilitiesRoot(), expectedRoot, "liabilitiesRoot ayarlanmali");
        assertEq(pol.currentEpoch(), 1, "epoch 1");
        assertEq(pol.epochTotalLiabilities(1), 10_000 ether, "toplam 10000 USD");
        assertEq(pol.epochLeafCount(1), 4, "4 yaprak");
        assertTrue(pol.epochSignatureEnforced(1), "AsiaCCS'26 gereksinimi kanitlanmali");

        // Her kullanıcı bağımsız olarak kendi yaprağını doğrular.
        for (uint256 i = 0; i < 4; i++) {
            bytes memory proof = _buildProof(leaves, i);
            assertTrue(
                pol.verifyLiability(users[i], balances[i], 1, sigs[i], proof),
                "her kullanici kendi yapragini dogrulayabilmeli"
            );
        }
    }

    // ============================================================
    // 2) OPERATÖR HİLESİ — uydurma kullanıcı → FAIL (imza yok)
    // ============================================================

    /// @notice Operatör 4. kullanıcının bakiyesini uydurur ama imzası yok
    ///         (başka bir anahtarla imzalanmış veya tamamen çöp) → tüm
    ///         yayın REVERT EDER (fail-closed). Hiçbir epoch yayınlanmaz.
    function testOperatorCannotFabricateUnsignedLeaf() public {
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _leaf(u0.addr, 1000 ether, 1);
        leaves[1] = _leaf(u1.addr, 2000 ether, 1);
        leaves[2] = _leaf(u2.addr, 3000 ether, 1);
        // UYDURMA: u3'ün bakiyesi 4000 ama imza YOK — bunun yerine
        // operatör kendi anahtarıyla (u0) imzalar.
        leaves[3] = _leaf(u3.addr, 4000 ether, 1);

        bytes[] memory sigs = new bytes[](4);
        sigs[0] = _sign(u0.privateKey, leaves[0]);
        sigs[1] = _sign(u1.privateKey, leaves[1]);
        sigs[2] = _sign(u2.privateKey, leaves[2]);
        sigs[3] = _sign(u0.privateKey, leaves[3]); // SAHTE imza (u3 değil)

        address[] memory users = new address[](4);
        users[0] = u0.addr;
        users[1] = u1.addr;
        users[2] = u2.addr;
        users[3] = u3.addr;
        uint256[] memory balances = new uint256[](4);
        balances[0] = 1000 ether;
        balances[1] = 2000 ether;
        balances[2] = 3000 ether;
        balances[3] = 4000 ether;

        vm.expectRevert("Kullanici imzasi gecersiz (yaprak imzalanmamis)");
        pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);

        // Fail-closed: hiçbir şey yayınlanmadı.
        assertEq(pol.epochCount(), 0, "fail-closed: epoch yayinlanmamali");
        assertEq(pol.liabilitiesRoot(), bytes32(0), "fail-closed: kok sifir kalmali");
    }

    // ============================================================
    // 3) KULLANICI REDDİ — imzalamaz → o yaprak DAHİL EDİLMEZ
    // ============================================================

    /// @notice u2 imzalamayı reddeder → operatör yalnızca imzalı 3 yaprakla
    ///         yayınlayabilir. u2'nin geçerli imzası olsa bile yaprak kökte
    ///         YOKTUR → verifyLiability false döner (dahil edilmedi).
    function testUnsignedUserOmittedFromRoot() public {
        // u2 REDDETTİ — yalnızca u0, u1, u3 imzaladı.
        bytes32[] memory signed = new bytes32[](3);
        signed[0] = _leaf(u0.addr, 1000 ether, 1);
        signed[1] = _leaf(u1.addr, 2000 ether, 1);
        signed[2] = _leaf(u3.addr, 4000 ether, 1);

        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(u0.privateKey, signed[0]);
        sigs[1] = _sign(u1.privateKey, signed[1]);
        sigs[2] = _sign(u3.privateKey, signed[2]);

        address[] memory users = new address[](3);
        users[0] = u0.addr;
        users[1] = u1.addr;
        users[2] = u3.addr;
        uint256[] memory balances = new uint256[](3);
        balances[0] = 1000 ether;
        balances[1] = 2000 ether;
        balances[2] = 4000 ether;

        bytes32 root = pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);
        assertEq(pol.epochLeafCount(1), 3, "3 yaprak (u2 dislandi)");

        // u2'nin KENDİ imzası GEÇERLİ ama yaprak kökte YOK:
        bytes32 l2 = _leaf(u2.addr, 3000 ether, 1);
        bytes memory sig2 = _sign(u2.privateKey, l2);
        // Ağaçtaki 3. pozisyon için yapısal olarak geçerli bir kanıt:
        // sibling = signed[2]'nin kendisi (tek-kalan kendisiyle eşleşir).
        bytes memory proofForSlot2 = _buildProof(signed, 2);

        assertFalse(
            pol.verifyLiability(u2.addr, 3000 ether, 1, sig2, proofForSlot2),
            "u2 imzalamadi -> yaprak kokte DEGIL -> false"
        );

        // İmzalayan 3 kullanıcı hala doğrulayabilir.
        assertTrue(
            pol.verifyLiability(u0.addr, 1000 ether, 1, sigs[0], _buildProof(signed, 0)),
            "u0 hala dogrulanabilmeli"
        );

        // Reddedilen kök ile tümü-imzalı kök FARKLI olmalı (u2 dışarıda).
        bytes32[] memory allFour = new bytes32[](4);
        allFour[0] = signed[0];
        allFour[1] = signed[1];
        allFour[2] = l2;
        allFour[3] = signed[2];
        assertTrue(root != pol.computeLiabilitiesRoot(allFour), "kokler farkli olmali");
    }

    // ============================================================
    // 4) TAHRİR — değeri/kökü değiştir → fail (İKİ KATMAN)
    // ============================================================

    /// @notice TAHRİR, iki katmanda da fail olur:
    ///   (A) YAYINDA: operatör u3'ün bakiyesini 4000 → 9999 tahrir eder ve
    ///       u3'ün GERÇEK (4000) imzasını takar. Kontrat yaprağı 9999
    ///       üzerinden yeniden hesapladığı için imza geçersiz olur → yayın
    ///       REVERT eder (fail-closed). Operatör, kullanıcıların imzaladığı
    ///       değerlerin DIŞINA çıkamaz; kökü de seçemez.
    ///   (B) DOĞRULAMADA: dürüst epoch yayınlandıktan sonra saldırgan
    ///       user0'a SAHTE Merkle kanıtı (kardeş yaprak tahrirli) sunar.
    ///       İmza geçerli olsa bile kök eşleşmez → verifyLiability false.
    function testTamperedBalanceAndForgedProofFail() public {
        // ---- (A) Yayında tahrir reddi ----
        bytes32 l3True = _leaf(u3.addr, 4000 ether, 1); // u3 GERÇEK değeri imzaladı
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = _leaf(u0.addr, 1000 ether, 1);
        leaves[1] = _leaf(u1.addr, 2000 ether, 1);
        leaves[2] = _leaf(u2.addr, 3000 ether, 1);
        leaves[3] = _leaf(u3.addr, 9999 ether, 1); // TAHRİR EDİLEN değer

        bytes[] memory sigs = new bytes[](4);
        sigs[0] = _sign(u0.privateKey, leaves[0]);
        sigs[1] = _sign(u1.privateKey, leaves[1]);
        sigs[2] = _sign(u2.privateKey, leaves[2]);
        sigs[3] = _sign(u3.privateKey, l3True); // 9999 değil, 4000 imzası

        address[] memory users = new address[](4);
        users[0] = u0.addr;
        users[1] = u1.addr;
        users[2] = u2.addr;
        users[3] = u3.addr;
        uint256[] memory balances = new uint256[](4);
        balances[0] = 1000 ether;
        balances[1] = 2000 ether;
        balances[2] = 3000 ether;
        balances[3] = 9999 ether; // tahrir

        vm.expectRevert("Kullanici imzasi gecersiz (yaprak imzalanmamis)");
        pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);

        // Fail-closed: tahrirli yayın hiç gerçekleşmedi.
        assertEq(pol.epochCount(), 0, "tahrirli yayin revert oldu");
        assertEq(pol.liabilitiesRoot(), bytes32(0), "kok sifir kalmali");

        // Aynı imzalarla DÜRÜST yayın (u3=4000) başarılıdır.
        balances[3] = 4000 ether;
        leaves[3] = l3True;
        bytes32 root = pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);
        assertTrue(root != bytes32(0), "durust yayin basarili");
        assertEq(pol.epochTotalLiabilities(1), 10_000 ether, "toplam dogru");

        // ---- (B) Doğrulamada sahte kanıt reddi ----
        // Doğru kanıt u0 için: sibling=l1 (bit=1), sonra sibling=h23 (bit=1).
        // SAHTE kanıt: l1 yerine tahrirli bir yaprak konur.
        bytes32 tamperedSibling = _leaf(u3.addr, 9999 ether, 1);
        bytes32 h23 = keccak256(abi.encode(leaves[2], leaves[3]));
        bytes memory forgedProof = abi.encodePacked(tamperedSibling, uint8(1), h23, uint8(1));

        assertFalse(
            pol.verifyLiability(u0.addr, 1000 ether, 1, sigs[0], forgedProof),
            "sahte Merkle kaniti reddedilmeli (tahrir tespit edildi)"
        );

        // Doğru kanıt hala geçerli — tahrir iyi niyetli kullanıcıyı etkilemez.
        assertTrue(
            pol.verifyLiability(u0.addr, 1000 ether, 1, sigs[0], _buildProof(leaves, 0)),
            "dogru kanit gecerli kalmali"
        );
    }

    // ============================================================
    // 5) YANLIŞ İMZA — verifyLiability reddeder (fail-closed doğrulama)
    // ============================================================

    /// @notice Doğru yaprak + doğru proof ama BAŞKASININ imzası →
    ///         verifyLiability revert ile fail-closed davranır.
    function testWrongSignerRejectedAtVerify() public {
        (bytes32[] memory leaves,) = _fourSignedLeaves();
        bytes[] memory sigs = _sigsForFour();
        address[] memory users = new address[](4);
        users[0] = u0.addr;
        users[1] = u1.addr;
        users[2] = u2.addr;
        users[3] = u3.addr;
        uint256[] memory balances = new uint256[](4);
        balances[0] = 1000 ether;
        balances[1] = 2000 ether;
        balances[2] = 3000 ether;
        balances[3] = 4000 ether;
        pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);

        // u1'in imzası u0'un yaprağı için sunulursa → imzalayan u0 değildir.
        vm.expectRevert("Imza gecersiz (kullanici imzalamamis)");
        pol.verifyLiability(u0.addr, 1000 ether, 1, sigs[1], _buildProof(leaves, 0));
    }
}
