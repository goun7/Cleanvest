// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanFXVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title CleanFXVault Test Suite
/// @notice 3 kademeli reserve, T+2 itfa kapisi, Optimize bayrak kilidi
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CleanFXVaultTest is Test {
    CleanFXVault public vault;
    MockUSDC public usdc;
    address public founder = address(0xF0D5000);
    address public alice = address(0xA11CE);

    function setUp() public {
        usdc = new MockUSDC();
        vault = new CleanFXVault(address(usdc));
        vault.transferOwnership(founder);

        usdc.mint(alice, 20_000_000 ether);
        usdc.mint(founder, 1_000_000 ether);
    }

    /// @notice Tier0: TVL < $250k -> kucuk depozit
    function testTier0Below250k() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, alice);
        vm.stopPrank();

        assert(uint256(vault.activeTier()) == uint256(ICleanvestVault.ReserveTier.Tier0));
        assertFalse(vault.treasuryBadgeValid(), "TVL < $250k -> Hazine rozeti GECERSIZ");
    }

    /// @notice Tier1: TVL >= $250k -> OUSG erisilebilir, rozet gecerli
    function testTier1At250k() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 250_000 ether);
        vault.deposit(250_000 ether, alice);
        vm.stopPrank();

        assert(uint256(vault.activeTier()) == uint256(ICleanvestVault.ReserveTier.Tier1));
        assertTrue(vault.treasuryBadgeValid(), "TVL >= $250k -> Hazine rozeti gecerli");
    }

    /// @notice Tier2: TVL >= $12.5M -> direkt BUIDL
    function testTier2At12_5M() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 12_500_000 ether);
        vault.deposit(12_500_000 ether, alice);
        vm.stopPrank();

        assert(uint256(vault.activeTier()) == uint256(ICleanvestVault.ReserveTier.Tier2));
    }

    /// @notice Getiri egrisi kademelere gore dogru (v1.2 mutabakat)
    function testYieldCurveMatchesV12() public {
        // Tier0: %3.05 (3.04 -> 305 bps esigi)
        vm.startPrank(alice);
        usdc.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, alice);
        vm.stopPrank();

        uint256 y0 = vault.currentSeniorYield();
        assertApproxEqAbs(y0, 0.0304 ether, 0.0002 ether, "Tier0 ~%3.04");

        // Tier1: %2.91
        vm.startPrank(alice);
        usdc.approve(address(vault), 150_000 ether);
        vault.deposit(150_000 ether, alice); // toplam 250k
        vm.stopPrank();

        uint256 y1 = vault.currentSeniorYield();
        assertApproxEqAbs(y1, 0.0291 ether, 0.0002 ether, "Tier1 ~%2.91");
    }

    /// @notice Optimize modu feed bagli degilken ACILAMAZ
    function testRevertOptimizeWithoutFeed() public {
        vm.prank(founder);
        vm.expectRevert("Optimize: Aave utilization feed bagli degil");
        vault.setOptimizeMode(true);
    }

    /// @notice Optimize modu feed baglaninca acilabilir
    function testOptimizeAfterFeed() public {
        address fakeFeed = address(0xFEED);

        vm.startPrank(founder);
        vault.setAaveUtilizationFeed(fakeFeed);
        vault.setOptimizeMode(true);
        vm.stopPrank();

        assert(uint256(vault.activeTier()) == uint256(ICleanvestVault.ReserveTier.TierOptimize));
    }

    /// @notice Gunluk %10 kotasi altinda anlik cekim
    function testInstantRedemptionWithinCap() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, alice);
        // Deposit sonrasi Alice USDC = 0 (100k hepsi vault'ta)
        assertEq(usdc.balanceOf(alice), 19_900_000 ether, "20M - 100k deposit = 19.9M kalan");

        // %10 = 10.000 anlik cekim (kota icinde)
        vault.withdraw(5_000 ether, alice, alice);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), 19_905_000 ether, "19.9M + 5.000 anlik");
    }

    /// @notice Itfa kapisi asla kilitlenmez - T+2 ile ertelenir
    function testRedemptionNeverLocked() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, alice);

        // %10 uzeri cekim -> T+2 kuyrugu (KILITLENMEZ, ertelenir)
        vault.withdraw(20_000 ether, alice, alice);
        vm.stopPrank();

        // Alice yine de USDC'sini aldi (ertelendi ama kilitlenmedi)
        assertEq(usdc.balanceOf(alice), 19_920_000 ether, "19.9M + 20.000 (T+2)");

        // T+2 kuyruk kaydi olustu
        assertGt(vault.queuedRedemptionUnlock(alice), 0, "T+2 kuyruk kaydi");
    }

    /// @notice Junior coverage orani %3
    function testJuniorCoverageRatio() public view {
        (, uint256 ratio) = (uint256(0), vault.juniorCoverageRatio());
        assertEq(ratio, 300, "Junior %3 hard invariant");
    }

    /// @notice Itfa kapisi parametreleri
    function testRedemptionGateParams() public view {
        (uint256 capPct, uint256 settleSec) = vault.redemptionGate();
        assertEq(capPct, 1000, "Gunluk %10 anlik kap");
        assertEq(settleSec, 2 days, "T+2 = 2 gun");
    }
}
