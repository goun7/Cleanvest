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
}
