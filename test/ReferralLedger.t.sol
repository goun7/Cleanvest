// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/ReferralLedger.sol";

/// @title ReferralLedger.t.sol - Referans sistemi testleri (docs/44)
/// @notice HyperLiquid modeli: %1.25 odul + %10 indirim (ilk $100K)
contract ReferralLedgerTest is Test {
    ReferralLedger internal ledger;
    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401);

    function setUp() public {
        ledger = new ReferralLedger();
    }

    // ============================================================
    // KAYIT TESTLERI
    // ============================================================

    function testRegisterReferral() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        assertEq(ledger.referredBy(bob), alice, "bob'u alice davet etti");
        assertTrue(ledger.referralLink(alice, bob), "baglanti var");
        assertEq(ledger.referralCount(alice), 1, "alice'in 1 daveti");
    }

    function testRegisterReferralRejectsSelf() public {
        vm.prank(alice);
        vm.expectRevert("Kendine referans olmaz");
        ledger.registerReferral(alice);
    }

    function testRegisterReferralRejectsZero() public {
        vm.prank(alice);
        vm.expectRevert("Referans sifir olamaz");
        ledger.registerReferral(address(0));
    }

    function testRegisterReferralRejectsDouble() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        vm.prank(bob);
        vm.expectRevert("Zaten referansin var");
        ledger.registerReferral(carol);
    }

    function testRegisterReferralRejectsCycle() public {
        // alice -> bob (alice davet edildi)
        vm.prank(alice);
        ledger.registerReferral(bob);

        // bob -> alice DONGUSU reddedilmeli
        vm.prank(bob);
        vm.expectRevert("Referans dongusu reddedildi");
        ledger.registerReferral(alice);
    }

    // ============================================================
    // ODUL TESTLERI
    // ============================================================

    function testDistributeReward() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        // bob $50K islem -> alice %1.25 = $625
        ledger.distributeReferralReward(bob, 50_000 ether);

        assertEq(ledger.referralEarnings(alice), 625 ether, "alice $625 kazandi");
        assertEq(ledger.totalRewardDistributed(), 625 ether, "toplam $625");
        assertTrue(ledger.rewardClaimed(bob), "bob'un odulu alindi");
    }

    function testRewardMathExact() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        // $100K * 1.25% = $1250
        ledger.distributeReferralReward(bob, 100_000 ether);
        assertEq(ledger.referralEarnings(alice), 1250 ether, "$100K -> $1250");
    }

    function testRewardCapped() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        // $200K islem -> yalnizca ilk $100K icin odul = $1250
        ledger.distributeReferralReward(bob, 200_000 ether);
        assertEq(ledger.referralEarnings(alice), 1250 ether, "tavan $1250");
    }

    function testRewardOnlyOnce() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        ledger.distributeReferralReward(bob, 50_000 ether);
        // 2. cagri: odul ZERIN zaten alindi
        ledger.distributeReferralReward(bob, 50_000 ether);

        assertEq(ledger.referralEarnings(alice), 625 ether, "odul tek seferlik");
    }

    function testDistributeRewardRequiresReferral() public {
        // bob'un referansi yok
        vm.expectRevert("Referans yok");
        ledger.distributeReferralReward(bob, 50_000 ether);
    }

    function testDistributeRewardOnlyOwner() public {
        vm.prank(bob);
        ledger.registerReferral(alice);

        vm.prank(carol);
        vm.expectRevert();
        ledger.distributeReferralReward(bob, 50_000 ether);
    }

    // ============================================================
    // INDIRIM TESTLERI
    // ============================================================

    function testHasReferralDiscount() public {
        assertFalse(ledger.hasReferralDiscount(bob), "referans yok -> indirim yok");

        vm.prank(bob);
        ledger.registerReferral(alice);
        assertTrue(ledger.hasReferralDiscount(bob), "referans var -> indirim var");

        // Odul alindiktan sonra indirim biter
        ledger.distributeReferralReward(bob, 100_000 ether);
        assertFalse(ledger.hasReferralDiscount(bob), "odul alindi -> indirim bitti");
    }

    function testReferralSummary() public {
        vm.prank(bob);
        ledger.registerReferral(alice);
        vm.prank(carol);
        ledger.registerReferral(alice);

        ledger.distributeReferralReward(bob, 100_000 ether);

        (uint256 count, uint256 earnings) = ledger.referralSummary(alice);
        assertEq(count, 2, "alice'in 2 daveti");
        assertEq(earnings, 1250 ether, "alice $1250 kazandi");
    }

    function testMultipleReferrersIndependent() public {
        // bob -> alice, carol -> alice
        vm.prank(bob);
        ledger.registerReferral(alice);
        vm.prank(carol);
        ledger.registerReferral(alice);

        // bob'un odulu alice'e
        ledger.distributeReferralReward(bob, 50_000 ether);
        assertEq(ledger.referralEarnings(alice), 625 ether, "bob icin $625");

        // carol'un odulu alice'e (ayri tavan)
        ledger.distributeReferralReward(carol, 50_000 ether);
        assertEq(ledger.referralEarnings(alice), 1250 ether, "toplam $1250");
    }
}
