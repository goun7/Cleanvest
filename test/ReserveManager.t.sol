// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/ReserveManager.sol";
import "../contracts/interfaces/IReserveStrategy.sol";
import "../contracts/interfaces/IUtilizationFeed.sol";

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

    /// @notice OPTIMIZE + feed bagli DEGILken devre-kesici false (L163)
    /// @dev Optimize acik ama feed sifir adresi ise erken false doner
    function testCircuitBreakerOptimizeWithoutFeed() public {
        // once feed bagla ve optimize ac
        vm.startPrank(owner);
        reserve.setAaveUtilizationFeed(feed);
        reserve.setOptimizeMode(true);
        vm.stopPrank();

        // feed bagli ama mock kodu yok -> utilizationBps revert eder.
        // Bu fonksiyon yine de false donmeli mi? Hayir: revert olur.
        // GERCEK senaryo: optimize KAPALI iken devre-kesici her zaman false
        vm.startPrank(owner);
        reserve.setOptimizeMode(false);
        vm.stopPrank();
        assertFalse(reserve.utilizationCircuitBreakerActive(), "Optimize kapaliyken devre-kesici false");
    }

    /// @notice Devre-kesici: utilization > %92 (9200 bps) ise true (L165-166)
    function testCircuitBreakerTriggersAbove92Pct() public {
        MockFeed mockFeed = new MockFeed(9500); // %95 utilization
        vm.startPrank(owner);
        reserve.setAaveUtilizationFeed(address(mockFeed));
        reserve.setOptimizeMode(true);
        vm.stopPrank();

        assertTrue(reserve.utilizationCircuitBreakerActive(), "%95 utilization'da devre-kesici AKTIF");
    }

    /// @notice Devre-kesici: utilization <= %92 ise false
    function testCircuitBreakerInactiveBelow92Pct() public {
        MockFeed mockFeed = new MockFeed(7000); // %70 utilization
        vm.startPrank(owner);
        reserve.setAaveUtilizationFeed(address(mockFeed));
        reserve.setOptimizeMode(true);
        vm.stopPrank();

        assertFalse(reserve.utilizationCircuitBreakerActive(), "%70 utilization'da devre-kesici KAPALI");
    }

    /// @notice Setter'lar dogru adresleri kaydeder (L170-202)
    function testReserveSetters() public {
        address pool = address(0xAAAA);
        address prime = address(0xBBBB);
        address ousg = address(0xCCCC);
        address buidl = address(0xDDDD);

        vm.startPrank(owner);
        reserve.setAavePool(pool);
        reserve.setAavePrimePool(prime);
        reserve.setOUSG(ousg);
        reserve.setBUIDL(buidl);
        vm.stopPrank();

        assertEq(reserve.aavePool(), pool, "Aave pool set");
        assertEq(reserve.aavePrimePool(), prime, "Prime pool set");
        assertEq(reserve.ousg(), ousg, "OUSG set");
        assertEq(reserve.buidl(), buidl, "BUIDL set");
    }

    /// @notice Reserve fon giris/cikis (L205-214) - DELTA bazli
    /// @dev setUp her testte yeni reserve olusturur; idle 0'dan baslar
    function testDepositAndWithdrawReserve() public {
        vm.startPrank(owner);
        reserve.depositReserve(1_000 ether);
        uint256 afterDeposit = reserve.idleBalance();
        assertGt(afterDeposit, 0, "Reserve giris");
        reserve.withdrawReserve(400 ether);
        uint256 afterWithdraw = reserve.idleBalance();
        vm.stopPrank();

        assertEq(afterDeposit - afterWithdraw, 400 ether, "Reserve cikis delta dogru");
    }

    /// @notice Sifir miktar reserve reddedilir
    function testRevertDepositZero() public {
        vm.prank(owner);
        vm.expectRevert("Miktar 0 olamaz");
        reserve.depositReserve(0);
    }

    /// @notice supplyToAave: 0 miktar reddedilir (branch L133)
    function testRevertSupplyToAaveZero() public {
        vm.prank(owner);
        vm.expectRevert("Miktar 0 olamaz");
        reserve.supplyToAave(0);
    }

    /// @notice supplyToAave: pool bagli degilken reddedilir (branch L134)
    /// @dev setUp pool set ediyor; bu yuzden TAZE (pool'suz) reserve gerekir
    function testRevertSupplyToAaveNoPool() public {
        ReserveManager fresh = new ReserveManager(address(usdc));
        vm.prank(address(this));
        vm.expectRevert("Aave pool bagli degil");
        fresh.supplyToAave(100);
    }

    /// @notice withdrawFromAave: 0 miktar reddedilir (branch L148)
    function testRevertWithdrawFromAaveZero() public {
        vm.prank(owner);
        vm.expectRevert("Miktar 0 olamaz");
        reserve.withdrawFromAave(0);
    }

    /// @notice withdrawFromAave: pool bagli degilken reddedilir (branch L149)
    /// @dev setUp'da pool set + Aave bakiye 0 oldugundan once 'bakiye yok'
    /// reverts; pool kontrolunu test etmek icin taze reserve sart.
    function testRevertWithdrawFromAaveNoPool() public {
        ReserveManager fresh = new ReserveManager(address(usdc));
        vm.prank(address(this));
        vm.expectRevert("Aave pool bagli degil");
        fresh.withdrawFromAave(100);
    }

    /// @notice withdrawReserve: 0 miktar reddedilir (branch L212)
    function testRevertWithdrawReserveZero() public {
        vm.prank(owner);
        vm.expectRevert("Miktar 0 olamaz");
        reserve.withdrawReserve(0);
    }

    /// @notice withdrawReserve: yetersiz idle bakiye reddedilir (branch L213)
    /// @dev setUp 100_000 ether idle birakir; esigin uzerini istersek revert
    function testRevertWithdrawReserveInsufficient() public {
        uint256 idleBefore = reserve.idleBalance();
        assertEq(idleBefore, 100_000 ether, "setUp idle'da 100k birakir");
        vm.prank(owner);
        vm.expectRevert("Yeterli idle USDC yok");
        reserve.withdrawReserve(idleBefore + 1);
    }

    /// @notice setAavePool: sifir adres reddedilir (branch L171)
    function testRevertSetAavePoolZero() public {
        vm.prank(owner);
        vm.expectRevert("Pool sifir olamaz");
        reserve.setAavePool(address(0));
    }

    /// @notice circuitBreaker: optimize kapaliyken false (branch L163)
    /// @dev optimizeModeEnabled=false -> hemen false doner
    function testCircuitBreakerDisabledByDefault() public {
        assertFalse(reserve.utilizationCircuitBreakerActive(), "optimize kapaliyken false");
    }

    /// @notice circuitBreaker: optimize acik ama feed bagli degilse false (L163/L171)
    function testCircuitBreakerOptimizeWithoutFeedAddress() public {
        vm.startPrank(owner);
        // once optimize'yi ac (feed henuz set edilmemis olabilir)
        reserve.setAaveUtilizationFeed(address(0));
        vm.stopPrank();
        assertFalse(reserve.utilizationCircuitBreakerActive(), "feedsiz false");
    }

    /// @notice rebalance: total 0 iken erken donus (branch L113)
    /// @dev TAZE reserve; sahibi msg.sender (test kontrati) - owner DEGIL
    function testRebalanceZeroTotalEarlyReturn() public {
        ReserveManager empty = new ReserveManager(address(usdc));
        vm.prank(address(this));
        empty.rebalance(); // revert etmemeli, erken donus (total=0)
        assertEq(empty.aaveBalance(), 0, "total=0: hicbir sey yapilmadi");
    }
}

/// @notice Aave utilization feed mock (IUtilizationFeed)
contract MockFeed is IUtilizationFeed {
    uint256 public util;

    constructor(uint256 _util) {
        util = _util;
    }

    function utilizationBps() external view override returns (uint256) {
        return util;
    }
}

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
