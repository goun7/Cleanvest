// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/ManipulationDetector.sol";
import "../contracts/MEVShield.sol";

/// @title AntiManipulation Test Suite (2026-09-29)
/// @notice README durust sinirlarinin kapanmasinin test-kanitli olcusu:
///         #2 replay (nonce takibi), #3 MEV (commit-reveal),
///         #5 manipulasyon tespiti (zincir-ustu risk skoru).
contract AntiManipulationTest is Test {
    CleanvestSettlement public settlement;
    address public owner = address(0x0ABE);
    address public solver = address(0x5010);

    bytes32 constant BATCH_ID = keccak256("am-batch-1");

    function setUp() public {
        settlement = new CleanvestSettlement();
        settlement.transferOwnership(owner);

        vm.prank(owner);
        settlement.registerSolver(solver);
    }

    /// @dev Test batch'i uretir ve kesinlestirir.
    function _settleBatch(uint256 volume) internal {
        ICleanvestSettlement.MatchedBatch memory batch = ICleanvestSettlement.MatchedBatch({
            batchId: BATCH_ID,
            orderCommitmentRoot: keccak256("am-root"),
            clearingPrice: 1_000 ether,
            totalVolume: volume,
            solverSignature: ""
        });
        bytes memory p = abi.encode(
            keccak256(abi.encode(batch.batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume))
        );
        vm.prank(solver);
        settlement.executeBatchSettlement(batch, p);
    }

    function _makeProof(
        bytes32 batchId,
        bytes32 root,
        uint256 price,
        uint256 volume
    ) internal pure returns (bytes memory) {
        return abi.encode(keccak256(abi.encode(batchId, root, price, volume)));
    }

    // ============================================================
    // #2 — REPLAY KORUMASI (nonce zincir-ustu takip)
    // ============================================================

    /// @notice Nonce tuketimi calisir ve kamusal olarak sorgulanir
    function testNonceConsumedAndQueryable() public {
        _settleBatch(10_000 ether);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000;
        amounts[1] = 2000;
        address[] memory users = new address[](2);
        users[0] = address(0xA11CE);
        users[1] = address(0xB0B);
        uint256[] memory nonces = new uint256[](2);
        nonces[0] = 1;
        nonces[1] = 2;

        vm.prank(solver);
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);

        assertTrue(settlement.isNonceConsumed(address(0xA11CE), 1), "nonce 1 tuketildi");
        assertTrue(settlement.isNonceConsumed(address(0xB0B), 2), "nonce 2 tuketildi");
        assertFalse(settlement.isNonceConsumed(address(0xA11CE), 99), "kullanilmamis nonce false");
    }

    /// @notice AYNI nonce ikinci kez REDDEDILIR (replay saldirisi durur)
    function testReplaySameNonceRejected() public {
        _settleBatch(10_000 ether);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        address[] memory users = new address[](1);
        users[0] = address(0xA11CE);
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 7;

        vm.prank(solver);
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);

        // Replay aynisi
        vm.prank(solver);
        vm.expectRevert("Nonce zaten kullanildi (replay)");
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);
    }

    /// @notice Kayitsiz solver nonce tuketemez
    function testNonceConsumeOnlySolver() public {
        _settleBatch(10_000 ether);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory users = new address[](1);
        users[0] = address(0xA11CE);
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 1;

        vm.prank(address(0xBEEF));
        vm.expectRevert("Kayitli RFQ solver degil");
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);
    }

    /// @notice Kesinlesmemis batch icin nonce tuketilemez
    function testNonceConsumeRequiresSettledBatch() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory users = new address[](1);
        users[0] = address(0xA11CE);
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 1;

        vm.prank(solver);
        vm.expectRevert("Batch henuzz kesinlesmedi");
        settlement.consumeNonces(amounts, users, nonces, keccak256("unsettled"));
    }

    /// @notice Uzunluk uyumsuzlugu reddedilir
    function testNonceConsumeLengthMismatch() public {
        _settleBatch(10_000 ether);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;
        address[] memory users = new address[](1);
        users[0] = address(0xA11CE);
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 1;

        vm.prank(solver);
        vm.expectRevert("Dizi uzunluklari uyumsuz");
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);
    }

    /// @notice Bos dizi reddedilir
    function testNonceConsumeEmptyRejected() public {
        _settleBatch(10_000 ether);

        uint256[] memory amounts = new uint256[](0);
        address[] memory users = new address[](0);
        uint256[] memory nonces = new uint256[](0);

        vm.prank(solver);
        vm.expectRevert("Bos dizi");
        settlement.consumeNonces(amounts, users, nonces, BATCH_ID);
    }

    // ============================================================
    // #3 — MEV KORUMASI (commit-reveal)
    // ============================================================

    /// @notice Commit/reveal dogru calisir: once commit, sonra uyum dogrulanir
    function testCommitRevealValid() public {
        bytes32 root = keccak256("mev-root");
        uint256 price = 1_000 ether;
        uint256 volume = 5_000 ether;

        vm.prank(solver);
        settlement.commitBatch(BATCH_ID, root, price, volume);

        // Commit kilitli: batch hen settle edilmedi ama commit kaydi var
        assertTrue(settlement.verifyBatchCommit(BATCH_ID, root, price, volume), "commit batch ile uyumlu");
    }

    /// @notice Yanlis icerikli reveal REDDEDILIR (commit kilitli)
    function testCommitRevealWrongContentRejected() public {
        bytes32 root = keccak256("mev-root");

        vm.prank(solver);
        settlement.commitBatch(BATCH_ID, root, 1_000 ether, 5_000 ether);

        // Farkli fiyat ile commit uyumsuz
        assertFalse(
            settlement.verifyBatchCommit(BATCH_ID, root, 2_000 ether, 5_000 ether),
            "yanlis fiyat commit ile uyumsuz olmali"
        );
    }

    /// @notice Ayni batch iki kez commit edilemez
    function testDoubleCommitRejected() public {
        bytes32 root = keccak256("mev-root");

        vm.startPrank(solver);
        settlement.commitBatch(BATCH_ID, root, 1_000 ether, 5_000 ether);

        vm.expectRevert("Batch zaten commit edildi");
        settlement.commitBatch(BATCH_ID, root, 1_000 ether, 5_000 ether);
        vm.stopPrank();
    }

    /// @notice Sifir batchId reddedilir
    function testCommitZeroBatchIdRejected() public {
        vm.prank(solver);
        vm.expectRevert("BatchId sifir olamaz");
        settlement.commitBatch(bytes32(0), keccak256("r"), 1_000 ether, 5_000 ether);
    }

    /// @notice Sifir kok reddedilir
    function testCommitZeroRootRejected() public {
        vm.prank(solver);
        vm.expectRevert("orderCommitmentRoot ZORUNLU");
        settlement.commitBatch(BATCH_ID, bytes32(0), 1_000 ether, 5_000 ether);
    }

    /// @notice Kayitsiz solver commit edemez
    function testCommitOnlySolver() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("Kayitli RFQ solver degil");
        settlement.commitBatch(BATCH_ID, keccak256("r"), 1_000 ether, 5_000 ether);
    }

    /// @notice Commit yasi kontrolu: hemen reveal edilebilir (MIN_COMMIT_AGE=1)
    function testCommitAgeOneBatch() public {
        bytes32 root = keccak256("mev-root");

        vm.prank(solver);
        settlement.commitBatch(BATCH_ID, root, 1_000 ether, 5_000 ether);

        // batchSequence henuz 0; reveal icin en az 1 batch gerekir
        // (executeBatchSettlement batchSequence'i artirir)
        assertEq(settlement.batchSequence(), 0, "baslangicta sira 0");

        // batch'i settle et -> sira 1 -> reveal artik mumkun
        _settleBatch(5_000 ether);
        assertEq(settlement.batchSequence(), 1, "settle sonrasi sira 1");

        // (commit hala gecerli olmali - ayni icerik)
        assertTrue(settlement.verifyBatchCommit(BATCH_ID, root, 1_000 ether, 5_000 ether));
    }

    /// @notice MEVShield kutuphanesi: computeCommitment deterministik
    function testMEVShieldComputeCommitmentDeterministic() public pure {
        bytes32 c1 = MEVShield.computeCommitment(BATCH_ID, bytes32(uint256(1)), 100, 200);
        bytes32 c2 = MEVShield.computeCommitment(BATCH_ID, bytes32(uint256(1)), 100, 200);
        assertEq(c1, c2, "ayni girdi ayni commit");

        bytes32 c3 = MEVShield.computeCommitment(BATCH_ID, bytes32(uint256(2)), 100, 200);
        assertNotEq(c1, c3, "farkli girdi farkli commit");
    }

    // ============================================================
    // #5 — MANIPULASYON TESPITI (risk skoru)
    // ============================================================

    /// @notice Temiz batch: risk skoru 0 (TEMIZ)
    function testDetectionCleanBatch() public {
        _settleBatch(100_000 ether);

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](3);
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 33_000 ether, 1);
        pairs[1] = ManipulationDetector.TradePair(address(0xA2), address(0xB2), 33_000 ether, 1);
        pairs[2] = ManipulationDetector.TradePair(address(0xA3), address(0xB3), 34_000 ether, 1);

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);

        assertEq(score, 0, "temiz batch risk 0");
        (uint256 rs, string memory label,,,) = settlement.lastDetectionSummary();
        assertEq(rs, 0, "kamusal ozet ayni");
        assertEq(label, "TEMIZ", "etiket TEMIZ");
    }

    /// @notice Round-trip (A->B->A) tespit edilir: pay > %40
    function testDetectionRoundTrip() public {
        _settleBatch(100_000 ether);

        // Tek cift batch'in %70'i -> round-trip sinyali
        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](2);
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 70_000 ether, 1);
        pairs[1] = ManipulationDetector.TradePair(address(0xA2), address(0xB2), 30_000 ether, 1);

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);

        assertGe(score, 35, "round-trip sinyali >= 35");
        (, string memory label,, bool roundTrip,) = settlement.lastDetectionSummary();
        assertTrue(roundTrip, "roundTrip flag true");
        // Tek sinyal (round-trip) = 35 puan -> DUSUK bandi (70+ gerekli YUKSEK icin)
        assertEq(label, "DUSUK", "tek sinyal DUSUK bandinda");
    }

    /// @notice Cift seli (pair flooding) tespit edilir: count > 5
    function testDetectionPairFlooding() public {
        _settleBatch(100_000 ether);

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](2);
        // count > MAX_PAIR_REPEATS (5) -> flooding
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 50_000 ether, 10);
        pairs[1] = ManipulationDetector.TradePair(address(0xA2), address(0xB2), 50_000 ether, 1);

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);

        assertGe(score, 25, "flooding sinyali >= 25");
        (,,,, bool flooding) = settlement.lastDetectionSummary();
        assertTrue(flooding, "flooding flag true");
    }

    /// @notice Hacim/islem dususu tespit edilir (Zwydak 2026 sinyali)
    function testDetectionVolumePerTxDrop() public {
        // Onceden normal bir batch raporla (baseline olussun)
        _settleBatch(100_000 ether);
        {
            ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](1);
            pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 10);
            vm.prank(solver);
            settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);
            // volumePerTx = 10_000
        }

        // Ikinci batch: ayni hacim ama 1000 kat fazla islem -> dusus sinyali
        bytes32 batch2 = keccak256("am-batch-2");
        {
            ICleanvestSettlement.MatchedBatch memory b = ICleanvestSettlement.MatchedBatch({
                batchId: batch2,
                orderCommitmentRoot: keccak256("r2"),
                clearingPrice: 1_000 ether,
                totalVolume: 100_000 ether,
                solverSignature: ""
            });
            bytes memory p = abi.encode(
                keccak256(abi.encode(b.batchId, b.orderCommitmentRoot, b.clearingPrice, b.totalVolume))
            );
            vm.prank(solver);
            settlement.executeBatchSettlement(b, p);
        }

        ManipulationDetector.TradePair[] memory pairs2 = new ManipulationDetector.TradePair[](1);
        // 100_000 hacim / 10_000 islem = 10 per tx (onceki 10_000 idi -> 1000x dusus)
        pairs2[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 10_000);

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(batch2, pairs2, 100_000 ether);

        assertGe(score, 40, "hacim/islem dususu >= 40");
        (,, bool volDrop,,) = settlement.lastDetectionSummary();
        assertTrue(volDrop, "volumePerTxDrop flag true");
    }

    /// @notice Tespit zorunlu modda: yuksek riskli batch REDDEDILIR
    function testDetectionEnforcedRejectsHighRisk() public {
        // Oncesi: normal bir batch baseline olusturur (volumePerTx = 10_000 ether).
        // (score 35 = round-trip sinyali; ama enforced DEGIL -> reddedilmez)
        _settleBatch(100_000 ether);
        {
            ManipulationDetector.TradePair[] memory pairs0 = new ManipulationDetector.TradePair[](1);
            pairs0[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 10);
            vm.prank(solver);
            settlement.reportBatchTrades(BATCH_ID, pairs0, 100_000 ether);
        }

        // Ikinci batch: hem round-trip (%70 pay) hem hacim/islem dususu -> 40+35 = 75 >= 70
        bytes32 batch2 = keccak256("enforced-high-risk");
        {
            ICleanvestSettlement.MatchedBatch memory b = ICleanvestSettlement.MatchedBatch({
                batchId: batch2,
                orderCommitmentRoot: keccak256("r2"),
                clearingPrice: 1_000 ether,
                totalVolume: 100_000 ether,
                solverSignature: ""
            });
            bytes memory p = abi.encode(
                keccak256(abi.encode(b.batchId, b.orderCommitmentRoot, b.clearingPrice, b.totalVolume))
            );
            vm.prank(solver);
            settlement.executeBatchSettlement(b, p);
        }

        // Zorunlu modu ac (sahip)
        vm.prank(owner);
        settlement.setDetectionEnforced(true);
        assertTrue(settlement.detectionEnforced(), "zorunlu mod acik");

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](2);
        // 70% pay -> round-trip; count 10_000 -> volumePerTx ~10 ether (baseline 3_000 ether) -> dusus
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 70_000 ether, 10_000);
        pairs[1] = ManipulationDetector.TradePair(address(0xA2), address(0xB2), 30_000 ether, 1);

        vm.prank(solver);
        vm.expectRevert("Manipulasyon riski: batch reddedildi");
        settlement.reportBatchTrades(batch2, pairs, 100_000 ether);
    }

    /// @notice Zorunlu modda: temiz batch hala kabul edilir
    function testDetectionEnforcedAllowsClean() public {
        _settleBatch(100_000 ether);

        vm.prank(owner);
        settlement.setDetectionEnforced(true);

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](3);
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 33_000 ether, 1);
        pairs[1] = ManipulationDetector.TradePair(address(0xA2), address(0xB2), 33_000 ether, 1);
        pairs[2] = ManipulationDetector.TradePair(address(0xA3), address(0xB3), 34_000 ether, 1);

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);
        assertEq(score, 0, "temiz batch zorunlu modda da gecer");
    }

    /// @notice setDetectionEnforced yalniz sahip
    function testDetectionEnforcedOnlyOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        settlement.setDetectionEnforced(true);
    }

    /// @notice Rapor yalniz kayitli solver
    function testReportOnlySolver() public {
        _settleBatch(100_000 ether);

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](1);
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 1);

        vm.prank(address(0xBEEF));
        vm.expectRevert("Kayitli RFQ solver degil");
        settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);
    }

    /// @notice Kesinlesmemis batch raporlanamaz
    function testReportRequiresSettled() public {
        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](1);
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 1);

        vm.prank(solver);
        vm.expectRevert("Batch kesinlesmedi");
        settlement.reportBatchTrades(keccak256("nope"), pairs, 100_000 ether);
    }

    /// @notice ManipulationDetector kutuphane: riskLabel bantlari
    function testRiskLabelBands() public pure {
        ManipulationDetector.DetectionResult memory r;
        r.riskScore = 0;
        assertEq(ManipulationDetector.riskLabel(r), "TEMIZ");

        r.riskScore = 25;
        assertEq(ManipulationDetector.riskLabel(r), "DUSUK");

        r.riskScore = 50;
        assertEq(ManipulationDetector.riskLabel(r), "ORTA");

        r.riskScore = 85;
        assertEq(ManipulationDetector.riskLabel(r), "YUKSEK");
    }

    /// @notice ManipulationDetector: isHighRisk esigi = 70
    function testIsHighRiskThreshold() public pure {
        ManipulationDetector.DetectionResult memory r;
        r.riskScore = 69;
        assertFalse(ManipulationDetector.isHighRisk(r), "69 yuksek degil");

        r.riskScore = 70;
        assertTrue(ManipulationDetector.isHighRisk(r), "70 yuksek");
    }

    /// @notice ManipulationDetector: tum sinyaller = maksimum 100 (dogma)
    function testScoreSaturatesAt100() public pure {
        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](2);
        // Round-trip (%70 pay) + flooding (count 10) -> 35+25 = 60
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 70_000 ether, 10);
        pairs[1] = ManipulationDetector.TradePair(address(0xA2), address(0xB2), 30_000 ether, 1);

        ManipulationDetector.Baseline memory b;
        b.lastVolumePerTx = 100_000 ether; // yuksek baseline -> dusus sinyali

        ManipulationDetector.DetectionResult memory r =
            ManipulationDetector.analyze(pairs, 100_000 ether, b);

        // 40 + 35 + 25 = 100
        assertEq(r.riskScore, 100, "tum sinyaller = 100 (dogma)");
    }

    /// @notice ManipulationDetector: baseline guncellemesi (kayar pencere)
    function testBaselineUpdate() public pure {
        ManipulationDetector.Baseline memory b;
        b = ManipulationDetector.updateBaseline(b, 100_000 ether, 10);
        // yeni perTx = 10_000 ether; (0*7 + 10_000e18*3)/10 = 3_000 ether
        assertEq(b.lastVolumePerTx, 3_000 ether, "ilk baseline");
        assertEq(b.batchCount, 1, "batch sayisi 1");

        b = ManipulationDetector.updateBaseline(b, 100_000 ether, 10);
        // (3_000e18*7 + 10_000e18*3)/10 = (21_000 + 30_000)/10 = 5_100 ether
        assertEq(b.lastVolumePerTx, 5_100 ether, "kayar pencere guncellendi");
    }

    /// @notice ManipulationDetector: sifir hacim/bos batch guvenli
    function testEmptyPairsSafe() public pure {
        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](0);
        ManipulationDetector.Baseline memory b;

        ManipulationDetector.DetectionResult memory r = ManipulationDetector.analyze(pairs, 0, b);
        assertEq(r.riskScore, 0, "bos batch temiz");
        assertEq(r.volumePerTx, 0, "sifir islem");
        assertFalse(r.volumePerTxDrop, "baseline yokken dusus sinyali YOK");
    }

    /// @notice ManipulationDetector: txCount sifir bolme korumasi
    function testZeroTxCountSafe() public pure {
        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](1);
        pairs[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 0);

        ManipulationDetector.Baseline memory b;
        b.lastVolumePerTx = 1_000_000 ether;

        ManipulationDetector.DetectionResult memory r = ManipulationDetector.analyze(pairs, 100_000 ether, b);
        // txCount 0 -> volumePerTx 0 -> dusus sinyali YOK (guvenli dusme)
        assertEq(r.volumePerTx, 0, "sifir bolme korumasi");
        assertFalse(r.volumePerTxDrop, "0 perTx ile dusus sinyali yanlis olmaz");
    }

    // ============================================================
    // DAR GOREV (2026-09-29): WASH / SPOOF / TAHRIR testleri
    // Her biri ayri bir tespit sinyalini hedefler:
    //   wash    -> roundTrip + pairFlooding
    //   spoof   -> volumePerTxDrop (diger iki sinyal ATLANMIS)
    //   tahrir  -> volume maskelense bile roundTrip yakalar
    // ============================================================

    /// @notice WASH TRADING: A<->B gidis-donus islemleri batch'e hakimse yakalanir.
    /// @dev Klasik wash-trade: A B'ye satar, B A'ya geri satar. Tek cift
    ///      batch hacminin %45'ini tutar (> %40 esigi) ve 8 kez tekrarlanir
    ///      (> 5 esigi). Iki sinyal birden: roundTrip(35) + flooding(25) = 60.
    function testWashTradingDetected() public {
        _settleBatch(100_000 ether);

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](3);
        // A -> B (8 gidis) ve B -> A (8 donus) = wash cifti
        pairs[0] = ManipulationDetector.TradePair(address(0xA11CE), address(0xB0B), 45_000 ether, 8);
        pairs[1] = ManipulationDetector.TradePair(address(0xB0B), address(0xA11CE), 45_000 ether, 8);
        // Seyrek gercel islemler (inandırıcılık icin)
        pairs[2] = ManipulationDetector.TradePair(address(0xC0FFEE), address(0xD00D), 10_000 ether, 2);

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(BATCH_ID, pairs, 100_000 ether);

        (uint256 rs,, bool volDrop, bool roundTrip, bool flooding) = settlement.lastDetectionSummary();

        assertEq(score, 60, "wash: roundTrip(35) + flooding(25) = 60");
        assertEq(rs, 60, "kamusal ozet ayni skor");
        assertTrue(roundTrip, "wash cifti %45 pay -> roundTrip yakalandi");
        assertTrue(flooding, "wash cifti 8 tekrar -> flooding yakalandi");
        assertFalse(volDrop, "ilk batch: baseline yok -> dusus sinyali beklenmez");
    }

    /// @notice SPOOFING: islem sayisi patlarken hacim sabit -> fake aktivite.
    /// @dev Spooferya yayvan: 50 farkli ciftte, her biri 5 islem (flooding
    ///      esiginin ALTINDA) ve %2 pay (roundTrip esiginin ALTINDA). Saldirgan
    ///      iki "gozukturucu" sinyali atlatir ama volumePerTx 400 ether'e
    ///      coker (baseline 3_000 ether, 3x dusus esigi 1_000) -> yakalanir.
    function testSpoofingFakeActivityDetected() public {
        // Batch 1: normal piyasa -> baseline olustur (volumePerTx = 3_000 ether)
        _settleBatch(100_000 ether);
        {
            ManipulationDetector.TradePair[] memory p0 = new ManipulationDetector.TradePair[](1);
            p0[0] = ManipulationDetector.TradePair(address(0xA1), address(0xB1), 100_000 ether, 10);
            vm.prank(solver);
            settlement.reportBatchTrades(BATCH_ID, p0, 100_000 ether);
        }

        // Batch 2: spoofing — 50 cift x 5 islem, hacim ayni ama 25x islem
        bytes32 batch2 = keccak256("spoof-batch");
        {
            ICleanvestSettlement.MatchedBatch memory b = ICleanvestSettlement.MatchedBatch({
                batchId: batch2,
                orderCommitmentRoot: keccak256("r-spoof"),
                clearingPrice: 1_000 ether,
                totalVolume: 100_000 ether,
                solverSignature: ""
            });
            bytes memory p = abi.encode(
                keccak256(abi.encode(b.batchId, b.orderCommitmentRoot, b.clearingPrice, b.totalVolume))
            );
            vm.prank(solver);
            settlement.executeBatchSettlement(b, p);
        }

        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](50);
        for (uint256 i = 0; i < 50; i++) {
            // her cift %2 pay, count 5 (flooding esigi >5'in altinda)
            pairs[i] =
                ManipulationDetector.TradePair(address(uint160(0x10000 + i)), address(uint160(0x20000 + i)), 2_000 ether, 5);
        }

        vm.prank(solver);
        uint256 score = settlement.reportBatchTrades(batch2, pairs, 100_000 ether);

        (,, bool volDrop, bool roundTrip, bool flooding) = settlement.lastDetectionSummary();

        assertEq(score, 40, "spoof: yalnizca volumePerTxDrop(40) sinyali");
        assertTrue(volDrop, "islem sayisi 25x artti, hacim/tx 400 ether'e coktu");
        assertFalse(roundTrip, "saldirgan roundTrip esigini atlatmisti");
        assertFalse(flooding, "saldirgan flooding esigini atlatmisti");
    }

    /// @notice TAHRIR (evasion): hacim/islem sinyali maskelendi, yine de yakalandi.
    /// @dev Saldirgan volumePerTxDrop'u bildigi icin islem basina hacmi normal
    ///      tutar (11_111 ether, baseline 10_000 -> dusus YOK) ve count'lari 3
    ///      tutar (flooding YOK). Ama wash islemler A<->B'de %60 oranda
    ///      toplandigi icin roundTrip sinyali onu yine de yakalar. Bu,
    ///      tespitin TEK degil COKLU bagimsiz sinyalleri oldugunu kanitlar:
    ///      bir sinyali atlatmak yeterli DEGILDIR.
    function testEvasionVolumeMaskedStillCaught() public pure {
        ManipulationDetector.TradePair[] memory pairs = new ManipulationDetector.TradePair[](3);
        pairs[0] = ManipulationDetector.TradePair(address(0xA11CE), address(0xB0B), 60_000 ether, 3);
        pairs[1] = ManipulationDetector.TradePair(address(0xB0B), address(0xA11CE), 30_000 ether, 3);
        pairs[2] = ManipulationDetector.TradePair(address(0xC0FFEE), address(0xD00D), 10_000 ether, 3);

        ManipulationDetector.Baseline memory b;
        b.lastVolumePerTx = 10_000 ether; // normal piyasa baseline

        ManipulationDetector.DetectionResult memory r = ManipulationDetector.analyze(pairs, 100_000 ether, b);

        // Saldirganin basarili maskelemesi: volumePerTx ~11_111 ether, baseline 10_000 ether
        assertGt(r.volumePerTx, 10_000 ether, "tahrir: per-tx hacim baseline'in uzerinde (maskeleme)");
        assertFalse(r.volumePerTxDrop, "tahrir: hacim sinyali maskelendi (basarili)");
        assertFalse(r.pairFlooding, "tahrir: count 3 -> flooding esigi alti");
        // ...ama roundTrip yine de yakalar:
        assertTrue(r.roundTripDetected, "%60 pay -> roundTrip tahriri yakaladi");
        assertEq(r.riskScore, 35, "yalnizca roundTrip(35) skoru");
        assertFalse(ManipulationDetector.isHighRisk(r), "35 < 70: inceleme sinyali, otomatik red DEGIL");
    }
}

/// @title MEVShield birim testleri (kutuphane seviyesi)
contract MEVShieldTest is Test {
    function testCommitStatesEnum() public pure {
        // Enum degerleri sabit
        assertEq(uint256(MEVShield.CommitState.None), 0);
        assertEq(uint256(MEVShield.CommitState.Committed), 1);
        assertEq(uint256(MEVShield.CommitState.Revealed), 2);
    }

    function testMinCommitAgeIsOne() public pure {
        assertEq(MEVShield.MIN_COMMIT_AGE, 1, "minimum commit yasi 1 batch");
    }

    function testMarkCommittedAndRevealed() public pure {
        MEVShield.CommitRecord memory rec;
        assertEq(uint256(rec.state), uint256(MEVShield.CommitState.None));

        rec = MEVShield.markCommitted(rec, bytes32(uint256(0x42)), 5, address(0xABCD));
        assertEq(uint256(rec.state), uint256(MEVShield.CommitState.Committed));
        assertEq(rec.commitmentHash, bytes32(uint256(0x42)));
        assertEq(rec.committedAtBatch, 5);
        assertEq(rec.committer, address(0xABCD));

        rec = MEVShield.markRevealed(rec);
        assertEq(uint256(rec.state), uint256(MEVShield.CommitState.Revealed));
    }

    function testCanRevealRequiresCommittedState() public pure {
        MEVShield.CommitRecord memory rec; // None
        assertFalse(
            MEVShield.canReveal(rec, bytes32(0), bytes32(0), 0, 0, 100),
            "None state reveal edilemez"
        );
    }

    function testCanRevealAgeGate() public pure {
        MEVShield.CommitRecord memory rec;
        rec = MEVShield.markCommitted(rec, MEVShield.computeCommitment(bytes32(uint256(1)), bytes32(uint256(2)), 3, 4), 5, address(0));

        // Yetersiz yas: currentBatchSeq = 5 (< 5 + 1)
        assertFalse(MEVShield.canReveal(rec, bytes32(uint256(1)), bytes32(uint256(2)), 3, 4, 5), "yas yetersiz");

        // Yeterli yas: 6 >= 5 + 1
        assertTrue(MEVShield.canReveal(rec, bytes32(uint256(1)), bytes32(uint256(2)), 3, 4, 6), "yas yeterli");
    }

    function testCanRevealWrongHash() public pure {
        MEVShield.CommitRecord memory rec;
        rec = MEVShield.markCommitted(rec, bytes32(uint256(0x11)), 0, address(0));

        // Farkli icerik -> hash uyumsuz
        assertFalse(MEVShield.canReveal(rec, bytes32(uint256(1)), bytes32(uint256(2)), 3, 4, 100), "hash uyumsuz");
    }

    function testCanRevealRevealedState() public pure {
        MEVShield.CommitRecord memory rec;
        bytes32 ch = MEVShield.computeCommitment(bytes32(uint256(1)), bytes32(uint256(2)), 3, 4);
        rec = MEVShield.markCommitted(rec, ch, 0, address(0));
        rec = MEVShield.markRevealed(rec);

        // Zaten reveal edilmis
        assertFalse(MEVShield.canReveal(rec, bytes32(uint256(1)), bytes32(uint256(2)), 3, 4, 100), "revealed state");
    }
}
