// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/ListingGate.sol";

/// @title ListingGate Test Suite
/// @notice AegisForge denetimi zorunlu; basvuru ucretsiz (harc modeli YOK)
contract ListingGateTest is Test {
    ListingGate public gate;
    address public owner = address(0x0ABE);
    address public oracle = address(0xA615);
    address public projectToken = address(0x7047);

    function setUp() public {
        gate = new ListingGate();
        gate.transferOwnership(owner);

        vm.prank(owner);
        gate.setAegisForgeOracle(oracle);
    }

    /// @notice Basvuru ucretsiz olmali (harc modeli YOK)
    function testApplicationFeeIsZero() public view {
        assertEq(gate.applicationFee(), 0, "Basvuru ucretsiz - harc modeli YOK");
    }

    /// @notice Yeni proje basvurabilir
    function testApplyForListing() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        assertNotEq(appId, bytes32(0), "Gecerli applicationId uretilmeli");

        (IListingGate.ListingStatus status,) = gate.getListingStatus(projectToken);
        assertTrue(uint256(status) == uint256(IListingGate.ListingStatus.Pending), "Durum Pending");
    }

    /// @notice Sifir token adresi reddedilmeli
    function testRevertZeroToken() public {
        vm.expectRevert("Gecersiz token adresi");
        gate.applyForListing(address(0), "Invalid");
    }

    /// @notice AegisForge onayi -> Verified
    function testAuditPassVerifies() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 1, 2, 3, false);

        assertTrue(gate.isVerified(projectToken), "85 skoru Verified olmali");
    }

    /// @notice Dusuk skor -> Rejected (MIN_CLEAN_SCORE = 70)
    function testLowScoreRejected() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 50, 0, 1, 2, 3, 4, false);

        (IListingGate.ListingStatus status,) = gate.getListingStatus(projectToken);
        assertTrue(uint256(status) == uint256(IListingGate.ListingStatus.Rejected), "50 skoru Reddedilmeli");
        assertFalse(gate.isVerified(projectToken));
    }

    /// @notice Oracle disinda kimse audit sonucu yazamaz
    function testRevertNonOracleAudit() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.expectRevert("Yalnizca AegisForge oracle");
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 90, 0, 0, 0, 1, 2, true);
    }

    /// @notice Ayni token icin ikinci basvuru reddedilmeli (Rejected haric)
    function testRevertDuplicateApplication() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.expectRevert("Zaten basvuru var");
        gate.applyForListing(projectToken, "TestToken");
    }

    /// @notice Reddedilen proje yeniden basvurabilir
    function testRejectedCanReapply() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, false, 30, 2, 1, 0, 0, 0, false);

        // Rejected durumda yeniden basvuru yapilabilmeli
        bytes32 appId2 = gate.applyForListing(projectToken, "TestToken v2");
        assertNotEq(appId2, bytes32(0));
    }

    /// @notice Owner oracle'i degistirebilir
    function testSetOracle() public {
        address newOracle = address(0xBEEF);

        vm.prank(owner);
        gate.setAegisForgeOracle(newOracle);

        assertEq(gate.aegisForgeOracle(), newOracle);
    }

    /// @notice Sifir oracle set edilemez
    function testRevertZeroOracle() public {
        vm.prank(owner);
        vm.expectRevert("Oracle sifir olamaz");
        gate.setAegisForgeOracle(address(0));
    }

    /// @notice PoV hash taahhudunu muhurler ve dogrular
    function testSealAndVerifyPovCommitment() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        bytes32 povHash = keccak256("aegisforge-pov-v1-payload-test");
        uint256 ts = block.timestamp;

        vm.prank(oracle);
        gate.sealPovCommitment(appId, povHash, ts, 2, 45);

        // Kamusal dogrulama
        assertTrue(gate.verifyPovCommitment(appId, povHash, ts), "Gecerli taahhut dogrulanmali");
        assertTrue(gate.commitmentSealed(appId), "Taahhut muhurlu");
    }

    /// @notice PoV hash sifir olamaz (ListingGate L294)
    function testRevertSealPovZeroHash() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        uint256 ts = block.timestamp;

        vm.prank(oracle);
        vm.expectRevert("PoV hash sifir olamaz");
        gate.sealPovCommitment(appId, bytes32(0), ts, 2, 45);
    }

    /// @notice Timestamp sifir olamaz (ListingGate L295) - acik dal kapatildi
    function testRevertSealPovZeroTimestamp() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        bytes32 povHash = keccak256("payload");

        vm.prank(oracle);
        vm.expectRevert("Timestamp sifir olamaz");
        gate.sealPovCommitment(appId, povHash, 0, 2, 45);
    }

    /// @notice Yanlis hash ile dogrulama false donmeli
    function testVerifyRejectsWrongHash() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        bytes32 povHash = keccak256("real-payload");
        uint256 ts = block.timestamp;

        vm.prank(oracle);
        gate.sealPovCommitment(appId, povHash, ts, 2, 45);

        bytes32 wrongHash = keccak256("forged-payload");
        assertFalse(gate.verifyPovCommitment(appId, wrongHash, ts), "Yanlis hash reddedilmeli");
    }

    /// @notice Yanlis timestamp ile dogrulama false donmeli (hash domain'i)
    function testVerifyRejectsWrongTimestamp() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        bytes32 povHash = keccak256("payload");
        uint256 ts = block.timestamp;

        vm.prank(oracle);
        gate.sealPovCommitment(appId, povHash, ts, 2, 45);

        // Ayni hash, farkli timestamp -> gecersiz (yeniden tarama farkli taahhut)
        assertFalse(gate.verifyPovCommitment(appId, povHash, ts + 1), "Yanlis timestamp reddedilmeli");
    }

    /// @notice Muhursuz basvuru dogrulanamaz
    function testVerifyUnsealedReturnsFalse() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");

        assertFalse(gate.verifyPovCommitment(appId, keccak256("x"), 1), "Muhursuz taahhut false");
        assertFalse(gate.commitmentSealed(appId));
    }

    /// @notice Oracle disinda kimse muhurleyemez
    function testRevertNonOracleSeal() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");

        vm.expectRevert("Yalnizca AegisForge oracle");
        gate.sealPovCommitment(appId, keccak256("payload"), block.timestamp, 1, 30);
    }

    /// @notice Sifir PoV hash reddedilmeli
    function testRevertZeroPovHash() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        vm.expectRevert("PoV hash sifir olamaz");
        gate.sealPovCommitment(appId, bytes32(0), block.timestamp, 0, 0);
    }

    /// @notice Kamusal CleanScore kaydi dogru yayimlanmali
    function testCleanScorePublished() public {
        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 1, 2, 3, false);

        ListingGate.CleanScoreRecord memory rec = gate.getCleanScore(projectToken);
        assertEq(rec.score, 85, "Skor 85");
        assertEq(uint8(rec.grade), uint8(bytes1("A")), "Not A");
        assertEq(rec.findingsCritical, 0, "Kritik yok");
        assertEq(rec.findingsHigh, 0, "High yok");
        assertEq(rec.findingsMedium, 1, "1 medium");
        assertEq(rec.findingsLow, 2, "2 low");
        assertEq(rec.findingsInfo, 3, "3 info");
        assertFalse(rec.fullAuditAvailable, "Tam audit yok ($299 kademe)");
    }

    /// @notice Yuksek kademe tam audit sunmali
    function testFullAuditAvailable() public {
        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 90, 0, 0, 0, 1, 2, true);

        ListingGate.CleanScoreRecord memory rec = gate.getCleanScore(projectToken);
        assertTrue(rec.fullAuditAvailable, "Tam audit VAR ($1.490+ kademe)");
        assertTrue(gate.fullAuditAvailable(projectToken), "Mapper de true");
    }

    /// @notice Skor 100'den buyuk olamaz
    function testRevertScoreAbove100() public {
        vm.prank(oracle);
        vm.expectRevert("Skor 0-100 arasinda olmali");
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 101, 0, 0, 0, 0, 0, false);
    }

    /// @notice Harf notu bantlari dogru olmali
    function testGradeBands() public {
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 95, 0,0,0,0,0, false);
        assertEq(uint8(gate.getCleanScore(projectToken).grade), uint8(bytes1("S")), "95 = S");
        gate.recordAuditResultForToken(bytes32(uint256(2)), projectToken, true, 85, 0,0,0,0,0, false);
        assertEq(uint8(gate.getCleanScore(projectToken).grade), uint8(bytes1("A")), "85 = A");
        gate.recordAuditResultForToken(bytes32(uint256(3)), projectToken, true, 70, 0,0,0,0,0, false);
        assertEq(uint8(gate.getCleanScore(projectToken).grade), uint8(bytes1("B")), "70 = B");
        gate.recordAuditResultForToken(bytes32(uint256(4)), projectToken, false, 50, 0,0,0,0,0, false);
        assertEq(uint8(gate.getCleanScore(projectToken).grade), uint8(bytes1("C")), "50 = C");
        gate.recordAuditResultForToken(bytes32(uint256(5)), projectToken, false, 30, 0,0,0,0,0, false);
        assertEq(uint8(gate.getCleanScore(projectToken).grade), uint8(bytes1("D")), "30 = D");
        vm.stopPrank();
    }


    /// @notice Ilk tarama Scan ($299) kademesi atar
    function testFirstAuditSetsScanTier() public {
        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 1, 2, 3, false);

        assertTrue(uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.Scan), "Ilk tarama = Scan");
    }

    /// @notice Kademeyi FuzzPatch'e yukselt -> tam audit acilir
    function testUpgradeToFuzzPatch() public {
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 1, 2, 3, false);
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.FuzzPatch);
        vm.stopPrank();

        assertTrue(uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.FuzzPatch), "Kademe FuzzPatch");
        assertTrue(gate.fullAuditAvailable(projectToken), "Tam audit ACILDI");
    }

    /// @notice Priority kademesi tam audit sunar
    function testUpgradeToPriority() public {
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.Priority);
        vm.stopPrank();

        assertTrue(uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.Priority), "Kademe Priority");
        assertTrue(gate.fullAuditAvailable(projectToken), "Priority tam audit");
    }

    /// @notice Gecersiz (enum disi) kademe reddedilmeli - L214 defense-in-depth
    /// @dev L211-213 yorumunda belgelendigi gibi: typed conversion
    ///      AuditTier(uint256(99)) Solidity 0.8'de conversion aninda Panic
    ///      verir (compiler katmani) ve raw calldata ile de ABI dekoderi enum
    ///      sinirini dogrulayip reddeder. Yani L214'e HIC ulasilamaz - bu
    ///      bilincli dead-by-design guvenlik katmanidir: decoder bir gun
    ///      atlanirsa (raw memory manipulasyonu, gelecekteki decoder bug'i)
    ///      L214 yine korur. Bu test decoder katmanini dogrular.
    function testRevertInvalidTierOutOfRange() public {
        // Raw calldata: uint8=99 enum disinda -> ABI dekoderi reddeder
        bytes memory cd = abi.encodeWithSignature(
            "upgradeAuditTier(address,uint8)",
            projectToken,
            uint8(99)
        );
        vm.prank(oracle);
        (bool ok, ) = address(gate).call(cd);
        assertFalse(ok, "enum disi raw calldata reddedilmeli (ABI decoder katmani)");
    }

    /// @notice Downgrade reddedilmeli
    function testRevertDowngrade() public {
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.FuzzPatch);

        vm.expectRevert("Yalnizca ileri yonlu yukseltme");
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.Scan);
        vm.stopPrank();
    }

    /// @notice Ayni kademe yeniden yukseltme reddedilmeli
    function testRevertSameTier() public {
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);

        vm.expectRevert("Yalnizca ileri yonlu yukseltme");
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.Scan);
        vm.stopPrank();
    }

    /// @notice None kademesinden yukseltme yapilabilir (L211 baslangic yolu)
    function testUpgradeFromNoneTier() public {
        vm.startPrank(oracle);
        // once None durumdan Scan'e
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.FuzzPatch);
        vm.stopPrank();
        assertEq(uint256(gate.getAuditTier(projectToken)), uint256(ListingGate.AuditTier.FuzzPatch));
    }

    /// @notice Oracle disinda kademe yukseltemez
    function testRevertNonOracleUpgrade() public {
        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);

        vm.expectRevert("Yalnizca AegisForge oracle");
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.FuzzPatch);
    }

    /// @notice Fiyat karti seffaf ve gizli degil
    /// @dev Fiyatlar docs/40 (2026-09-27) ile guncellendi
    function testPriceCard() public {
        (uint256 scan, uint256 scanHuman, uint256 fuzzPatch, uint256 priority) = gate.getPriceCard();
        assertEq(scan, 199, "Scan $199");
        assertEq(scanHuman, 399, "ScanHuman $399");
        assertEq(fuzzPatch, 990, "FuzzPatch $990");
        assertEq(priority, 4900, "Priority $4.900");
    }

    /// @notice Yeni ScanHuman kademeleri ileri yonlu yukseltilebilir (docs/40)
    function testScanHumanTierUpgradeable() public {
        // Basvuru -> ilk tarama Scan atar (recordAuditResultForToken ile)
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);
        assertTrue(uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.Scan), "Ilk tarama Scan");
        // Scan -> ScanHuman ileri yonlu (izinli)
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.ScanHuman);
        assertTrue(uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.ScanHuman), "ScanHuman'a yukseltildi");
        // ScanHuman hala tam audit DEGIL (fullAuditAvailable false kalmali)
        assertFalse(gate.fullAuditAvailable(projectToken), "ScanHuman tam audit vermez");
        vm.stopPrank();
    }

    /// @notice ScanHuman'a Scan atlandiktan sonra direkt gidilebilir ( downgrade YOK )
    function testScanHumanSkippableButNotDowngrade() public {
        vm.startPrank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85, 0, 0, 0, 0, 0, false);
        // Scan -> FuzzPatch atlayabilir (ScanHuman'i atlamak serbest)
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.FuzzPatch);
        assertTrue(uint256(gate.getAuditTier(projectToken)) == uint256(ListingGate.AuditTier.FuzzPatch), "FuzzPatch'a atlandi");
        // FuzzPatch -> ScanHuman geri DONULEMEZ (downgrade YOK)
        vm.expectRevert("Yalnizca ileri yonlu yukseltme");
        gate.upgradeAuditTier(projectToken, ListingGate.AuditTier.ScanHuman);
        vm.stopPrank();
    }


    /// @notice getListingStatus dogru applicationId'den score alir (timestamp icerir)
    function testGetListingStatusScoreLookup() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        gate.recordAuditResultForToken(appId, projectToken, true, 85, 0, 0, 1, 2, 3, false);

        // getListingStatus dogru score donmeli (eski bug: timestamp'siz hash -> 0)
        (, uint256 score) = gate.getListingStatus(projectToken);
        assertEq(score, 85, "Score dogru applicationId'den alindi");

        // lastApplicationId kaydedildi
        assertEq(gate.lastApplicationId(projectToken), appId, "Son basvuru id takip edildi");
    }

    /// @notice recordAuditResult applicationToken eslemesinden GERCEK token adresi emit eder
    /// @dev Teknik borc kapatma kodunun testi: eskiden address(0) emit ediliyordu.
    ///      Coverage: L144-150 kapsamamasi giderildi.
    function testRecordAuditResultResolvesRealToken() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");

        // applicationToken eslemesi applyForListing icinde set edilmeli
        assertEq(gate.applicationToken(appId), projectToken, "Esleme gercek token adresi icermeli");

        // recordAuditResult oracle disinda cagrilamaz
        vm.expectRevert();
        gate.recordAuditResult(appId, true, 88);

        // oracle cagrisi: GERCEK token adresi ile AuditRecorded emit edilmeli
        vm.prank(oracle);
        vm.expectEmit(true, true, true, true);
        emit ListingGate.AuditRecorded(appId, projectToken, true, 88);
        gate.recordAuditResult(appId, true, 88);

        // score kaydedildi
        assertEq(gate.applicationScore(appId), 88, "Score applicationId'ye yazildi");
    }
}
