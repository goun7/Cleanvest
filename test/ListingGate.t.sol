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
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 85);

        assertTrue(gate.isVerified(projectToken), "85 skoru Verified olmali");
    }

    /// @notice Dusuk skor -> Rejected (MIN_CLEAN_SCORE = 70)
    function testLowScoreRejected() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 50);

        (IListingGate.ListingStatus status,) = gate.getListingStatus(projectToken);
        assertTrue(uint256(status) == uint256(IListingGate.ListingStatus.Rejected), "50 skoru Reddedilmeli");
        assertFalse(gate.isVerified(projectToken));
    }

    /// @notice Oracle disinda kimse audit sonucu yazamaz
    function testRevertNonOracleAudit() public {
        gate.applyForListing(projectToken, "TestToken");

        vm.expectRevert("Yalnizca AegisForge oracle");
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, true, 90);
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
        gate.recordAuditResultForToken(bytes32(uint256(1)), projectToken, false, 30);

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
        gate.sealPovCommitment(appId, povHash, ts);

        // Kamusal dogrulama
        assertTrue(gate.verifyPovCommitment(appId, povHash, ts), "Gecerli taahhut dogrulanmali");
        assertTrue(gate.commitmentSealed(appId), "Taahhut muhurlu");
    }

    /// @notice Yanlis hash ile dogrulama false donmeli
    function testVerifyRejectsWrongHash() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        bytes32 povHash = keccak256("real-payload");
        uint256 ts = block.timestamp;

        vm.prank(oracle);
        gate.sealPovCommitment(appId, povHash, ts);

        bytes32 wrongHash = keccak256("forged-payload");
        assertFalse(gate.verifyPovCommitment(appId, wrongHash, ts), "Yanlis hash reddedilmeli");
    }

    /// @notice Yanlis timestamp ile dogrulama false donmeli (hash domain'i)
    function testVerifyRejectsWrongTimestamp() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");
        bytes32 povHash = keccak256("payload");
        uint256 ts = block.timestamp;

        vm.prank(oracle);
        gate.sealPovCommitment(appId, povHash, ts);

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
        gate.sealPovCommitment(appId, keccak256("payload"), block.timestamp);
    }

    /// @notice Sifir PoV hash reddedilmeli
    function testRevertZeroPovHash() public {
        bytes32 appId = gate.applyForListing(projectToken, "TestToken");

        vm.prank(oracle);
        vm.expectRevert("PoV hash sifir olamaz");
        gate.sealPovCommitment(appId, bytes32(0), block.timestamp);
    }
}
