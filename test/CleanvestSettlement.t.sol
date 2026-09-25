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
        settlement.executeBatchSettlement(batch, bytes("proof"));

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
        settlement.executeBatchSettlement(batch, bytes("proof"));
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
        settlement.executeBatchSettlement(batch, bytes("proof"));

        vm.expectRevert("Batch zaten kesinlesti");
        settlement.executeBatchSettlement(batch, bytes("proof"));
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
        settlement.executeBatchSettlement(batch, bytes("proof"));
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
        settlement.executeBatchSettlement(batch, bytes("proof"));
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
        settlement.executeBatchSettlement(batch, bytes("proof"));

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
}
