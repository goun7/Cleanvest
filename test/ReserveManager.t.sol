// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/ReserveManager.sol";
import "../contracts/interfaces/IReserveStrategy.sol";

/// @title ReserveManager Test Suite
/// @notice 3 kademeli reserve: Aave/OUSG/BUIDL/Prime/idle + OPTIMIZE devre-kesici
contract ReserveManagerTest is Test {
    ReserveManager public reserve;
    MockUSDC public usdc;
    address public owner = address(0x0ABE);
    address public aavePool = address(0xA4E0);
    address public feed = address(0xFEED);

    function setUp() public {
        usdc = new MockUSDC();
        reserve = new ReserveManager(address(usdc));
        reserve.transferOwnership(owner);

        vm.prank(owner);
        reserve.setAavePool(aavePool);

        // Aave pool'a USDC transfer onayi (mock)
        usdc.mint(address(reserve), 100_000 ether);
        vm.prank(owner);
        reserve.depositReserve(100_000 ether);
    }

    /// @notice Tier0: TVL < $250k
    function testTier0Below250k() public {
        assert(uint256(reserve.activeTier()) == uint256(IReserveStrategy.ReserveTier.Tier0));
    }

    /// @notice Tier1: TVL >= $250k (OUSG eşiği)
    function testTier1At250k() public {
        vm.prank(owner);
        reserve.depositReserve(250_000 ether);

        assert(uint256(reserve.activeTier()) == uint256(IReserveStrategy.ReserveTier.Tier1));
    }

    /// @notice Tier2: TVL >= $12.5M (BUIDL eşiği)
    function testTier2At12_5M() public {
        usdc.mint(address(reserve), 12_500_000 ether);
        vm.prank(owner);
        reserve.depositReserve(12_500_000 ether);

        assert(uint256(reserve.activeTier()) == uint256(IReserveStrategy.ReserveTier.Tier2));
    }

    /// @notice Tier0 hedef dagilimi: %73/0/%15/%12
    function testTier0Allocation() public view {
        IReserveStrategy.Allocation memory a = reserve.targetAllocation(
            IReserveStrategy.ReserveTier.Tier0
        );
        assertEq(a.aaveBps, 7300, "Tier0 Aave %73");
        assertEq(a.rwaBps, 0, "Tier0 RWA 0 (OUSG min $100k)");
        assertEq(a.primeBps, 1500, "Tier0 Prime %15");
        assertEq(a.idleBps, 1200, "Tier0 idle %12 (SAFE)");
    }

    /// @notice Tier1 hedef dagilimi: %33/40/%15/%12
    function testTier1Allocation() public view {
        IReserveStrategy.Allocation memory a = reserve.targetAllocation(
            IReserveStrategy.ReserveTier.Tier1
        );
        assertEq(a.aaveBps, 3300, "Tier1 Aave %33");
        assertEq(a.rwaBps, 4000, "Tier1 OUSG %40");
        assertEq(a.primeBps, 1500, "Tier1 Prime %15");
        assertEq(a.idleBps, 1200, "Tier1 idle %12");
    }

    /// @notice Tum kademelerin bps toplami 10000 olmali
    function testAllocationsSumTo10000() public view {
        for (uint256 t = 0; t <= 3; t++) {
            IReserveStrategy.Allocation memory a = reserve.targetAllocation(
                IReserveStrategy.ReserveTier(t)
            );
            assertEq(a.aaveBps + a.rwaBps + a.primeBps + a.idleBps, 10000, "Toplam 10000");
        }
    }

    /// @notice Rebalance hedef dagilima gelir
    function testRebalanceTier0() public {
        vm.prank(owner);
        reserve.rebalance();

        uint256 total = reserve.totalReserve();
        assertEq(reserve.aaveBalance(), (total * 7300) / 10000, "Aave %73");
        assertEq(reserve.idleBalance(), (total * 1200) / 10000, "Idle %12");
    }

    /// @notice Aave supply idle'dan Aave'ye tasir
    function testSupplyToAave() public {
        uint256 idleBefore = reserve.idleBalance();
        uint256 aaveBefore = reserve.aaveBalance();

        vm.prank(owner);
        reserve.supplyToAave(100_000 ether);

        assertEq(reserve.idleBalance(), idleBefore - 100_000 ether, "Idle azaldi");
        assertEq(reserve.aaveBalance(), aaveBefore + 100_000 ether, "Aave artti");
    }

    /// @notice Aave withdraw Aave'den idle'ye tasir (itfa likiditesi)
    function testWithdrawFromAave() public {
        vm.startPrank(owner);
        reserve.supplyToAave(100_000 ether);

        uint256 idleBefore = reserve.idleBalance();
        reserve.withdrawFromAave(50_000 ether);
        vm.stopPrank();

        assertEq(reserve.idleBalance(), idleBefore + 50_000 ether, "Idle artti");
    }

    /// @notice Yetersiz idle ile Aave supply reddedilir
    function testRevertSupplyExceedsIdle() public {
        vm.prank(owner);
        vm.expectRevert("Yeterli idle USDC yok");
        reserve.supplyToAave(2_000_000 ether);
    }

    /// @notice Yetersiz Aave ile withdraw reddedilir
    function testRevertWithdrawExceedsAave() public {
        vm.prank(owner);
        vm.expectRevert("Yeterli Aave bakiye yok");
        reserve.withdrawFromAave(1_000_000 ether);
    }

    /// @notice OPTIMIZE mod feed yokken acilamaz
    function testRevertOptimizeWithoutFeed() public {
        vm.prank(owner);
        vm.expectRevert("OPTIMIZE: utilization feed bagli degil");
        reserve.setOptimizeMode(true);
    }

    /// @notice OPTIMIZE mod feed bagliyken acilir
    function testOptimizeMode() public {
        vm.startPrank(owner);
        reserve.setAaveUtilizationFeed(feed);
        reserve.setOptimizeMode(true);
        vm.stopPrank();

        assert(uint256(reserve.activeTier()) == uint256(IReserveStrategy.ReserveTier.TierOptimize));
    }

    /// @notice Devre-kesici: SAFE modda her zaman false
    function testCircuitBreakerSafeMode() public {
        assertFalse(reserve.utilizationCircuitBreakerActive(), "SAFE modda devre-kesici kapali");
    }
}

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
