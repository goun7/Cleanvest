// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/interfaces/ICleanvestSettlement.sol";

/// @title CleanvestSettlement Test Suite (Faz-3)
/// @notice 400ms FBA batch settlement: anti-collusion, orderCommitmentRoot, $5k cap
contract CleanvestSettlementTest is Test {
    CleanvestSettlement public settlement;
    address public owner = address(0x0ABE);
    address public solver = address(0x5010);

    bytes32 constant BATCH_ID = keccak256("batch-1");
    bytes32 constant COMMIT_ROOT = keccak256("merkle-orders-1");

    function setUp() public {
        settlement = new CleanvestSettlement();
        settlement.transferOwnership(owner);

        vm.prank(owner);
        settlement.registerSolver(solver);
    }

    /// @notice T_batch 400ms kilitli

    /// @notice Batch icin gecerli 32-bayt kanit uretir.
    function _makeProof(
        bytes32 batchId,
        bytes32 commitmentRoot,
        uint256 clearingPrice,
        uint256 totalVolume
    ) internal pure returns (bytes memory) {
        return abi.encode(
            keccak256(abi.encode(batchId, commitmentRoot, clearingPrice, totalVolume))
        );
    }

    function testTBatchIs400ms() public view {
        assertEq(settlement.T_BATCH_MS(), 400, "T_batch = 400ms (Budish FBA)");
    }

    /// @notice Soguk baslangic tavani $5.000
    function testColdStartCap5000() public view {
        assertEq(settlement.orderSizeCap(), 5_000 ether, "Soguk baslangic $5.000");
    }

    /// @notice Emir tavani enforce edilir
    function testEnforceOrderSizeRejects() public view {
        settlement.enforceOrderSize(5_000 ether); // tam sinir OK
        settlement.enforceOrderSize(1 ether);     // kucuk OK
    }

    /// @notice Tavani asan emir reddedilir
    function testRevertOrderAboveCap() public {
        vm.expectRevert("Emir tavani asildi: $5.000 soguk baslangic");
        settlement.enforceOrderSize(5_001 ether);
    }

    /// @notice Anti-collusion: dQ=0 -> eps0 = 0.15%
    function testAntiCollusionBaseline() public view {
        uint256 eps = settlement.antiCollusionBound(0, 1_000_000 ether);
        assertEq(eps, 15, "dQ=0 -> eps = 0.15% (15 bps)");
    }

    /// @notice Anti-collusion: buyuk dQ -> eps buyur (boyut-farkli)
    function testAntiCollusionGrowsWithSize() public view {
        // dQ/L < 1/KAPPA -> tamsayi bolme 0 -> eps0 (dogru davranis)
        uint256 epsSmall = settlement.antiCollusionBound(10_000 ether, 1_000_000 ether);
        assertEq(epsSmall, 15, "Kucuk dQ -> eps0'ya yuvarlanir");

        // dQ = L/2 -> 5 * 0.5 = 2 -> eps = 17 (boyut-farkli artis)
        uint256 epsBig = settlement.antiCollusionBound(500_000 ether, 1_000_000 ether);
        assertGt(epsBig, epsSmall, "Buyuk dQ -> buyuk eps (boyut-farkli)");

        // dQ = L -> 5 * 1 = 5 -> eps = 20
        uint256 epsHuge = settlement.antiCollusionBound(1_000_000 ether, 1_000_000 ether);
        assertGt(epsHuge, epsBig, "dQ=L -> eps maksimum artis");
    }

    /// @notice Anti-collusion tavan: %5'i gecmez
    function testAntiCollusionCapped() public view {
        // Asiri buyuk dQ (L'nin 1000 kati) -> tavan 500 bps
        uint256 eps = settlement.antiCollusionBound(1_000_000_000 ether, 1_000_000 ether);
        assertEq(eps, 500, "eps tavan = %5 (500 bps)");
    }

    /// @notice L=0 -> eps0 (bolum sifir korumasi)
    function testAntiCollusionZeroLiquidity() public view {
        uint256 eps = settlement.antiCollusionBound(1_000_000 ether, 0);
        assertEq(eps, 15, "L=0 -> eps0 (guvenli dusme)");
    }

    /// @notice Batch settlement: orderCommitmentRoot ZORUNLU
    function testSettleBatch() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 1_000 ether,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        vm.prank(solver);
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));

        assertTrue(settlement.isBatchSettled(BATCH_ID), "Batch kesinlesti");
    }

    /// @notice orderCommitmentRoot sifir reddedilir (front-run kalkani)
    function testRevertZeroCommitmentRoot() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: bytes32(0),
            clearingPrice: 1_000 ether,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        vm.prank(solver);
        vm.expectRevert("orderCommitmentRoot ZORUNLU");
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));
    }

    /// @notice Cift batch kesinlestirme reddedilir
    function testRevertDoubleSettlement() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 1_000 ether,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        vm.startPrank(solver);
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));

        vm.expectRevert("Batch zaten kesinlesti");
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));
        vm.stopPrank();
    }

    /// @notice Sifir takas fiyat reddedilir
    function testRevertZeroClearingPrice() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 0,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        vm.prank(solver);
        vm.expectRevert("Takas fiyat 0 olamaz");
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));
    }

    /// @notice Kayitsiz solver batch gonderemez
    function testRevertUnregisteredSolver() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 1_000 ether,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        vm.prank(address(0xBEEF));
        vm.expectRevert("Kayitli RFQ solver degil");
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));
    }

    /// @notice Lift trigger: hacim > $250k -> tavani kaldirir
    function testLiftByVolume() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 1_000 ether,
            totalVolume: 300_000 ether, // > $250k
            solverSignature: ""
        });

        vm.prank(solver);
        settlement.executeBatchSettlement(batch, _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume));

        assertTrue(settlement.sizeCapLifted(), "Hacim lift trigger tetikledi");
        assertEq(settlement.orderSizeCap(), type(uint256).max, "Tavan kaldirildi");
    }

    /// @notice Lift trigger: 2+ solver -> tavani kaldirir
    function testLiftBySolverCount() public {
        address solver2 = address(0x5011);

        vm.prank(owner);
        settlement.registerSolver(solver2);

        assertTrue(settlement.sizeCapLifted(), "2 solver lift trigger tetikledi");
    }

    /// @notice Chainlink feed baglanabilir (harici oracle)
    function testSetChainlinkFeed() public {
        address feed = address(0xFEED);

        vm.prank(owner);
        settlement.setChainlinkFeed(feed);

        assertEq(settlement.chainlinkPriceFeed(), feed);
    }

    /// @notice Sifir feed reddedilir
    function testRevertZeroFeed() public {
        vm.prank(owner);
        vm.expectRevert("Feed sifir olamaz");
        settlement.setChainlinkFeed(address(0));
    }

    /// @notice Gecersiz kanit reddedilir (batch butunlik korumasi)
    function testRevertInvalidProof() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 1_000 ether,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        // Yanlis kanit (baska batch'in hash'i)
        bytes memory badProof = abi.encode(keccak256("forged"));
        vm.prank(solver);
        vm.expectRevert("Kanit batch ile uyumsuz");
        settlement.executeBatchSettlement(batch, badProof);
    }

    /// @notice 32 bayt olmayan kanit reddedilir
    function testRevertWrongLengthProof() public {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: COMMIT_ROOT,
            clearingPrice: 1_000 ether,
            totalVolume: 500_000 ether,
            solverSignature: ""
        });

        vm.prank(solver);
        vm.expectRevert("Kanit 32 bayt olmali");
        settlement.executeBatchSettlement(batch, bytes("short"));
    }

    /// @notice registerSolver: sifir adres reddedilir (branch L171)
    function testRevertRegisterSolverZero() public {
        vm.prank(owner);
        vm.expectRevert("Solver sifir olamaz");
        settlement.registerSolver(address(0));
    }

    /// @notice registerSolver: ayni solver tekrar kaydedilemez (branch L172)
    /// @dev setUp solver'i zaten kaydetti
    function testRevertRegisterSolverDuplicate() public {
        vm.prank(owner);
        vm.expectRevert("Zaten kayitli");
        settlement.registerSolver(solver);
    }

    // ============================================================
    // MERKLE EMIR TAAHHUDU TESTLERI (2026-09-28)
    // Rust ureticisi (merkle/src/lib.rs) ile birebit ayni kural.
    // ============================================================

    /// @notice leafHash Rust ile ayni paketlemeyi yapar
    function testLeafHashMatchesAbiEncoding() public {
        // keccak256(abi.encode(1000, address(1), 7))
        bytes32 expected = keccak256(abi.encode(uint256(1000), address(1), uint256(7)));
        assertEq(settlement.leafHash(1000, address(1), 7), expected, "leafHash abi.encode ile ayni");
    }

    /// @notice Tek yaprak: root = leaf
    function testComputeRootSingleLeaf() public {
        bytes32 leaf = settlement.leafHash(1000, address(1), 1);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        assertEq(settlement.computeRoot(leaves), leaf, "Tek yaprakta root = leaf");
    }

    /// @notice Iki yaprak: root = keccak256(abi.encode(l0, l1))
    function testComputeRootTwoLeaves() public {
        bytes32 l0 = settlement.leafHash(1000, address(1), 1);
        bytes32 l1 = settlement.leafHash(2000, address(2), 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 expected = keccak256(abi.encode(l0, l1));
        assertEq(settlement.computeRoot(leaves), expected, "Iki yaprak dogru kok");
    }

    /// @notice Uc yaprak (tek kalan kendisiyle): Rust ile ayni kural
    function testComputeRootOddLeaves() public {
        bytes32 l0 = settlement.leafHash(1, address(1), 1);
        bytes32 l1 = settlement.leafHash(2, address(2), 2);
        bytes32 l2 = settlement.leafHash(3, address(3), 3);
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = l0;
        leaves[1] = l1;
        leaves[2] = l2;
        // Katman 1: [h(l0,l1), h(l2,l2)]
        bytes32 p0 = keccak256(abi.encode(l0, l1));
        bytes32 p1 = keccak256(abi.encode(l2, l2));
        bytes32 expected = keccak256(abi.encode(p0, p1));
        assertEq(settlement.computeRoot(leaves), expected, "Tek kalan kendisiyle eslesir");
    }

    /// @notice Bos agac reddedilir
    function testComputeRootEmptyReverts() public {
        bytes32[] memory leaves = new bytes32[](0);
        vm.expectRevert("Bos agac koku tanimsiz");
        settlement.computeRoot(leaves);
    }

    /// @notice Gecerli Merkle kaniti kabul edilir (2 yaprak)
    function testVerifyMerkleProofValid() public {
        bytes32 l0 = settlement.leafHash(1000, address(1), 1);
        bytes32 l1 = settlement.leafHash(2000, address(2), 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);

        // l0 icin kanit: sibling = l1, sagda (bit=1)
        bytes memory proof = abi.encodePacked(l1, uint8(1));
        assertTrue(settlement.verifyMerkleProof(l0, proof, root), "Gecerli kanit kabul edilmeli");
    }

    /// @notice Yanlis kanit REDDEDILMELI (farkli sibling)
    function testVerifyMerkleProofWrongSiblingRejected() public {
        bytes32 l0 = settlement.leafHash(1000, address(1), 1);
        bytes32 l1 = settlement.leafHash(2000, address(2), 2);
        bytes32 wrong = settlement.leafHash(9999, address(9), 9);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);

        // Yanlis sibling ile kanit
        bytes memory proof = abi.encodePacked(wrong, uint8(1));
        assertFalse(settlement.verifyMerkleProof(l0, proof, root), "Yanlis kanit reddedilmeli");
    }

    /// @notice Yanlis yaprak (ayni kanit) REDDEDILMELI
    function testVerifyMerkleProofWrongLeafRejected() public {
        bytes32 l0 = settlement.leafHash(1000, address(1), 1);
        bytes32 l1 = settlement.leafHash(2000, address(2), 2);
        bytes32 wrong = settlement.leafHash(9999, address(9), 9);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);

        // l1'in kaniti ama wrong leaf ile dogrulanamaz
        bytes memory proof = abi.encodePacked(l0, uint8(0));
        assertFalse(settlement.verifyMerkleProof(wrong, proof, root), "Yanlis yaprak reddedilmeli");
    }

    /// @notice Yanlis kok REDDEDILMELI
    function testVerifyMerkleProofWrongRootRejected() public {
        bytes32 l0 = settlement.leafHash(1000, address(1), 1);
        bytes32 l1 = settlement.leafHash(2000, address(2), 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 root = settlement.computeRoot(leaves);
        bytes32 badRoot = bytes32(uint256(root) ^ 1);

        bytes memory proof = abi.encodePacked(l1, uint8(1));
        assertFalse(settlement.verifyMerkleProof(l0, proof, badRoot), "Yanlis kok reddedilmeli");
    }

    /// @notice 3 yaprakli agacta her yaprak icin kanit gecerli (Rust ile ayni)
    function testVerifyMerkleProofOddTreeAllLeaves() public {
        bytes32 l0 = settlement.leafHash(1, address(1), 1);
        bytes32 l1 = settlement.leafHash(2, address(2), 2);
        bytes32 l2 = settlement.leafHash(3, address(3), 3);
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = l0;
        leaves[1] = l1;
        leaves[2] = l2;
        bytes32 root = settlement.computeRoot(leaves);

        // Katman 1: p0 = h(l0,l1), p1 = h(l2,l2)
        bytes32 p0 = keccak256(abi.encode(l0, l1));
        bytes32 p1 = keccak256(abi.encode(l2, l2));

        // l0: sibling l1 (sagda), sonra p1 (sagda)
        bytes memory p_l0 = abi.encodePacked(l1, uint8(1), p1, uint8(1));
        assertTrue(settlement.verifyMerkleProof(l0, p_l0, root), "l0 kaniti gecerli");

        // l1: sibling l0 (solda), sonra p1 (sagda)
        bytes memory p_l1 = abi.encodePacked(l0, uint8(0), p1, uint8(1));
        assertTrue(settlement.verifyMerkleProof(l1, p_l1, root), "l1 kaniti gecerli");

        // l2: sibling l2 (sagda — kendisiyle), sonra p0 (solda)
        bytes memory p_l2 = abi.encodePacked(l2, uint8(1), p0, uint8(0));
        assertTrue(settlement.verifyMerkleProof(l2, p_l2, root), "l2 kaniti gecerli");
    }

    /// @notice executeBatchSettlement GERCEK Merkle koku ile calisir
    /// @dev Guvenlik acigi kapanmasi: artik sabit degil, uretilmis kok
    function testExecuteBatchWithRealMerkleRoot() public {
        bytes32 l0 = settlement.leafHash(1000, address(1), 1);
        bytes32 l1 = settlement.leafHash(2000, address(2), 2);
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = l0;
        leaves[1] = l1;
        bytes32 realRoot = settlement.computeRoot(leaves);

        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: realRoot,
            clearingPrice: 1000 ether,
            totalVolume: 3000 ether,
            solverSignature: ""
        });
        bytes memory batchProof = _makeProof(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume);

        vm.prank(solver);
        settlement.executeBatchSettlement(batch, batchProof);
        assertTrue(settlement.batchSettled(BATCH_ID), "Batch GERCEK Merkle koku ile kesinlesti");
    }
}
