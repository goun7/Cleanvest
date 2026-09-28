// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/interfaces/ICleanvestSettlement.sol";

/// @title Yaprak Imza Testleri — Guvenlik Aciginin TAM Kapanmasi
/// @notice EIP-191 personal_sign: kullanici imzasi -> yaprak -> kok zinciri.
///         Rust (merkle/src/signed.rs) ile BIREBIT ayni sema.
contract SignedMerkleTest is Test {
    CleanvestSettlement public settlement;

    /// @notice Standart anvil test anahtari #0 (test-only, PUBLIC).
    ///         anvil --mnemonic "test test ... junk" ile uretilir.
    ///         PRIVATE_KEY DEGIL — mainnet degeri YOK.
    uint256 constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant ANVIL_ADDR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        settlement = new CleanvestSettlement();
    }

    /// @notice Yardimci: EIP-191 imzasi uretir (vm.sign ile)
    function _signLeaf(bytes32 leaf) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ANVIL_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    // ============================================================
    // EIP-191 OZET ESLESMESI
    // ============================================================

    /// @notice toEthSignedMessageHash Rust ile birebir
    function testToEthSignedMessageHashMatchesEIP191() public {
        bytes32 leaf = keccak256("test-leaf");
        bytes32 expected = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        assertEq(settlement.toEthSignedMessageHash(leaf), expected, "EIP-191 ozeti ayni olmali");
    }

    /// @notice vm.sign ile uretilen imza recoverSigner ile ANVIL_ADDR vermeli
    function testRecoverSignerReturnsCorrectAddress() public {
        bytes32 leaf = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes memory sig = _signLeaf(leaf);
        address recovered = settlement.recoverSigner(leaf, sig);
        assertEq(recovered, ANVIL_ADDR, "Imzalayan adres geri kazanilmali");
    }

    // ============================================================
    // YANLIS IMZA / YANLIS SIGNER — EN KRITIK TESTLER
    // ============================================================

    /// @notice YANLIS IMZA REDDEDILMELI (en kritik guvenlik testi)
    function testWrongSignatureRejected() public {
        bytes32 leaf = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes memory sig = _signLeaf(leaf);
        // Imzayi boz (bytes1 -> uint8 -> xor -> bytes1)
        sig[10] = bytes1(uint8(uint8(sig[10]) ^ 0xff));

        assertFalse(
            settlement.verifyLeafSignature(leaf, sig, ANVIL_ADDR),
            "YANLIS imza REDDEDILMELI"
        );
    }

    /// @notice YANLIS SIGNER REDDEDILMELI
    function testWrongSignerRejected() public {
        bytes32 leaf = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes memory sig = _signLeaf(leaf);
        address impostor = address(0x1234);

        assertFalse(
            settlement.verifyLeafSignature(leaf, sig, impostor),
            "YANLIS imzalayan REDDEDILMELI"
        );
    }

    /// @notice YANLIS UZUNLUKTA imza reddedilmeli
    function testShortSignatureReverts() public {
        bytes32 leaf = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes memory shortSig = abi.encodePacked(bytes32(0), bytes32(0));

        vm.expectRevert("Imza 65 bayt olmali");
        settlement.recoverSigner(leaf, shortSig);
    }

    /// @notice Sifir signer reddedilmeli (ecrecover(0) adresi 0 doner)
    function testZeroSignerRejected() public {
        bytes32 leaf = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes memory sig = _signLeaf(leaf);
        assertFalse(
            settlement.verifyLeafSignature(leaf, sig, address(0)),
            "Sifir adres reddedilmeli"
        );
    }

    // ============================================================
    // DOGRU IMZA + DOGRU PROOF -> PASS (TAM KANIT ZINIRI)
    // ============================================================

    /// @notice Tam kanit zinciri: imza + Merkle inclusion birlikte gecerli
    function testVerifySignedOrderValid() public {
        bytes32 l0 = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes32 l1 = settlement.leafHash(2000, ANVIL_ADDR, 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);

        bytes memory sig0 = _signLeaf(l0);
        bytes memory proof = abi.encodePacked(l1, uint8(1));

        assertTrue(
            settlement.verifySignedOrder(l0, sig0, ANVIL_ADDR, proof, root),
            "Imza + Merkle birlikte gecerli olmali"
        );
    }

    /// @notice Dogru imza ama YANLIS Merkle proof -> REDDEDILMELI
    function testValidSignatureButWrongProofRejected() public {
        bytes32 l0 = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes32 l1 = settlement.leafHash(2000, ANVIL_ADDR, 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);

        bytes memory sig0 = _signLeaf(l0);
        bytes32 wrong = settlement.leafHash(9999, address(9), 9);
        bytes memory badProof = abi.encodePacked(wrong, uint8(1));

        assertFalse(
            settlement.verifySignedOrder(l0, sig0, ANVIL_ADDR, badProof, root),
            "Imza gecerli ama kanit yanlis -> REDDEDILMELI"
        );
    }

    /// @notice YANLIS imza + dogru proof -> REDDEDILMELI
    function testWrongSignatureButValidProofRejected() public {
        bytes32 l0 = settlement.leafHash(1000, ANVIL_ADDR, 1);
        bytes32 l1 = settlement.leafHash(2000, ANVIL_ADDR, 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);

        // l1'in imzasi ama l0 icin kullanilirsa
        bytes memory wrongSig = _signLeaf(l1);
        bytes memory proof = abi.encodePacked(l1, uint8(1));

        assertFalse(
            settlement.verifySignedOrder(l0, wrongSig, ANVIL_ADDR, proof, root),
            "Yanlis imza + dogru kanit -> REDDEDILMELI"
        );
    }

    // ============================================================
    // RUST <-> SOLIDITY CAPRAZ KANIT (kritik)
    // merkle/examples/cross_check_signed.rs ile AYNI imza
    // ============================================================

    /// @notice Rust'in urettigi imza Solidity ecrecover ile AYNI adresi vermeli
    /// @dev merkle/examples/cross_check_signed.rs ciktisi ile birebir karsilastirma
    function testRustSignatureVerifiesOnChain() public {
        // Rust ile uretilmis yaprak + imza (cross_check_signed.rs ciktisi)
        bytes32 leaf = 0x93e6b7c07a8739f4fb863563972c03adbb6d6b44f5f7822dd6749699b937baff;
        bytes memory rustSig = hex"ab122946e29666da8779e79975439f58e30f4335ed4df74df35057e41fae7ce602c73cd6449ee052cfc2bc5ff37958f003b6c88b5610f2b02934bbca12a216bd1c";
        address recovered = settlement.recoverSigner(leaf, rustSig);
        assertEq(recovered, ANVIL_ADDR, "Rust imzasi Solidity'de AYNI adresi vermeli");
    }

    /// @notice Rust ile uretilen imzayla tam kanit zinciri zincirde dogrulanmali
    function testRustSignedOrderFullChainOnChain() public {
        // Rust cross_check_signed.rs ciktisi (ayni emir: amount=1000, ANVIL_ADDR, nonce=1)
        bytes32 leaf = 0x93e6b7c07a8739f4fb863563972c03adbb6d6b44f5f7822dd6749699b937baff;
        bytes memory rustSig = hex"ab122946e29666da8779e79975439f58e30f4335ed4df74df35057e41fae7ce602c73cd6449ee052cfc2bc5ff37958f003b6c88b5610f2b02934bbca12a216bd1c";
        // Tek yaprakli agac: root = leaf
        bytes32 root = leaf;

        // verifySignedOrder: imza + Merkle (tek yaprakta proof bos)
        assertTrue(
            settlement.verifySignedOrder(leaf, rustSig, ANVIL_ADDR, "", root),
            "Rust imzasi + tam kanit zinciri zincirde gecerli olmali"
        );
    }

    /// @notice 3 yaprakli agacta tum imzalar + kanitlar gecerli
    function testOddSignedTreeAllLeavesValid() public {
        bytes32 l0 = settlement.leafHash(1, ANVIL_ADDR, 1);
        bytes32 l1 = settlement.leafHash(2, ANVIL_ADDR, 2);
        bytes32 l2 = settlement.leafHash(3, ANVIL_ADDR, 3);
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = l0;
        leaves[1] = l1;
        leaves[2] = l2;
        bytes32 root = settlement.computeRoot(leaves);

        bytes32 p0 = keccak256(abi.encode(l0, l1));
        bytes32 p1 = keccak256(abi.encode(l2, l2));

        // Her yaprak: imza + tam Merkle kaniti
        assertTrue(
            settlement.verifySignedOrder(l0, _signLeaf(l0), ANVIL_ADDR,
                abi.encodePacked(l1, uint8(1), p1, uint8(1)), root),
            "l0 tam kanit gecerli"
        );
        assertTrue(
            settlement.verifySignedOrder(l1, _signLeaf(l1), ANVIL_ADDR,
                abi.encodePacked(l0, uint8(0), p1, uint8(1)), root),
            "l1 tam kanit gecerli"
        );
        assertTrue(
            settlement.verifySignedOrder(l2, _signLeaf(l2), ANVIL_ADDR,
                abi.encodePacked(l2, uint8(1), p0, uint8(0)), root),
            "l2 tam kanit gecerli"
        );
    }
}
