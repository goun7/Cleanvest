// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/interfaces/ICleanvestSettlement.sol";

/// @title TradingFee.t.sol - UC KADEMELI komisyon modeli testleri
/// @notice docs/44 (2026-09-26): HyperLiquid arastirmasina dayali model.
/// @dev Her kademenin dogru fee verdigini ve edge case'leri dogrular.
contract TradingFeeTest is Test {
    CleanvestSettlement internal settlement;
    address internal owner = address(this);
    address internal solver = address(0xBEEF);
    address internal feeRecipient = address(0xFEE);

    function setUp() public {
        settlement = new CleanvestSettlement();
        settlement.registerSolver(solver);
        settlement.setProtocolFeeRecipient(feeRecipient);
    }

    // ============================================================
    // KADEME TESTLERI
    // ============================================================

    function testFeeWelcomeTierIsZero() public view {
        // ilk $10K: %0 (hosgeldin)
        assertEq(settlement.tradingFeeBps(0, false), 0, "0 hacim ucretsiz");
        assertEq(settlement.tradingFeeBps(5_000 ether, false), 0, "5K ucretsiz");
        assertEq(settlement.tradingFeeBps(9_999 ether, false), 0, "9.999K ucretsiz");
        assertEq(settlement.tradingFeeBps(9_999 ether, true), 0, "9.999K maker ucretsiz");
    }

    function testFeeStandardTier() public view {
        // $10K - $1M: taker 35, maker 25
        assertEq(settlement.tradingFeeBps(10_000 ether, false), 35, "10K taker 35");
        assertEq(settlement.tradingFeeBps(10_000 ether, true), 25, "10K maker 25");
        assertEq(settlement.tradingFeeBps(100_000 ether, false), 35, "100K taker 35");
        assertEq(settlement.tradingFeeBps(100_000 ether, true), 25, "100K maker 25");
    }

    function testFeeProTier() public view {
        // $1M+: taker 30, maker 20
        assertEq(settlement.tradingFeeBps(1_000_000 ether, false), 30, "1M taker 30");
        assertEq(settlement.tradingFeeBps(1_000_000 ether, true), 20, "1M maker 20");
        assertEq(settlement.tradingFeeBps(5_000_000 ether, false), 30, "5M taker 30");
        assertEq(settlement.tradingFeeBps(5_000_000 ether, true), 20, "5M maker 20");
    }

    function testFeeBoundaryExact() public view {
        // Sinir degerleri: 10K tam ustunde standart, 1M tam ustunde pro
        assertEq(settlement.tradingFeeBps(9_999.999 ether, false), 0, "altinda welcome");
        assertEq(settlement.tradingFeeBps(10_000 ether, false), 35, "tam 10K standart");
        assertEq(settlement.tradingFeeBps(999_999 ether, false), 35, "1M altinda standart");
        assertEq(settlement.tradingFeeBps(1_000_000 ether, false), 30, "tam 1M pro");
    }

    // ============================================================
    // HESAPLAMA TESTLERI (gercek USD degerleri)
    // ============================================================

    function testFeeAmountStandardTaker() public {
        // 100K * 0.035% = 35 USD
        uint256 fee = settlement.tradingFeeBps(100_000 ether, false);
        uint256 amount = (100_000 ether * fee) / 100_000;
        assertEq(amount, 35 ether, "100K taker fee = $35");
    }

    function testFeeAmountProTaker() public {
        // 2M * 0.030% = 600 USD
        uint256 fee = settlement.tradingFeeBps(2_000_000 ether, false);
        uint256 amount = (2_000_000 ether * fee) / 100_000;
        assertEq(amount, 600 ether, "2M taker fee = $600");
    }

    function testFeeAmountMakerDiscount() public {
        // 100K maker = 25 USD (taker 35 - 10 indirim)
        uint256 fee = settlement.tradingFeeBps(100_000 ether, true);
        uint256 amount = (100_000 ether * fee) / 100_000;
        assertEq(amount, 25 ether, "100K maker fee = $25");
    }

    // ============================================================
    // recordFeeRevenue TESTLERI
    // ============================================================

    function testRecordFeeRevenue() public {
        vm.prank(solver);
        settlement.recordFeeRevenue(100_000 ether, false);

        // Fee = 100K * 35 / 100000 = 35 USD (standart, solver'in ilk islemi)
        assertEq(settlement.protocolRevenue(), 35 ether, "gelir $35");
        assertEq(settlement.userVolume(solver), 100_000 ether, "solver hacmi 100K");
    }

    function testRecordFeeRevenueWelcomeThenStandard() public {
        // 1. islem: 5K (welcome, %0)
        vm.prank(solver);
        settlement.recordFeeRevenue(5_000 ether, false);
        assertEq(settlement.protocolRevenue(), 0, "welcome ucretsiz");

        // 2. islem: 6K (toplam 11K -> standart)
        vm.prank(solver);
        settlement.recordFeeRevenue(6_000 ether, false);
        // Fee = 6K * 35 / 100000 = 2.1 USD
        assertEq(settlement.protocolRevenue(), 2.1 ether, "2. islem standart fee");
    }

    function testRecordFeeRevenueOnlySolver() public {
        // Solver olmayan cagiramaz
        vm.expectRevert();
        settlement.recordFeeRevenue(100_000 ether, false);
    }

    function testRecordFeeRevenueRequiresRecipient() public {
        // Fee recipient ayarli degilse revert
        CleanvestSettlement fresh = new CleanvestSettlement();
        fresh.registerSolver(solver);
        vm.prank(solver);
        vm.expectRevert("Komisyon cuzuDani ayarli degil");
        fresh.recordFeeRevenue(100_000 ether, false);
    }

    function testSetProtocolFeeRecipient() public {
        address newRecipient = address(0xCAFE);
        settlement.setProtocolFeeRecipient(newRecipient);
        assertEq(settlement.protocolFeeRecipient(), newRecipient, "yeni recipient");
    }

    function testSetProtocolFeeRecipientRejectsZero() public {
        vm.expectRevert("Komisyon cuzuDani sifir olamaz");
        settlement.setProtocolFeeRecipient(address(0));
    }

    function testSetProtocolFeeRecipientOnlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        settlement.setProtocolFeeRecipient(address(0xCAFE));
    }
}
