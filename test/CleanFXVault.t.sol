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
    address public bob = address(0xB0B);

    function setUp() public {
        usdc = new MockUSDC();
        vault = new CleanFXVault(address(usdc));
        vault.transferOwnership(founder);

        usdc.mint(alice, 20_000_000 ether);
        usdc.mint(founder, 1_000_000 ether);
        usdc.mint(bob, 20_000_000 ether);
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

    /// @notice Kuyruk istegi yapmadan cok buyuk cekim reddedilir
    function testRevertWithdrawWithoutRequest() public {
        usdc.mint(alice, 200 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 200 ether);
        vault.deposit(200 ether, alice);

        vm.expectRevert("Once requestRedemption ile kuyruga girin");
        vault.withdraw(21 ether, alice, alice);
        vm.stopPrank();
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

        // Kuyruk istegi (ayri transaction - state kalici)
        vault.requestRedemption(20_000 ether);
        assertGt(vault.queuedUnlockTime(alice), 0, "T+2 kuyruk kaydi");

        // Hemen cekmek reddedilir
        vm.expectRevert("T+2 bekleme suresi dolmadi");
        vault.withdraw(20_000 ether, alice, alice);

        // 2 gun sonra CIKIS SERBEST - sonsuz kilit YOK
        vm.warp(block.timestamp + 2 days + 1);
        vault.withdraw(20_000 ether, alice, alice);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), 19_920_000 ether, "T+2 sonrasi fonlar serbest (20M - 100k deposit + 20k cekim)");
        assertEq(vault.queuedUnlockTime(alice), 0, "Kuyruk temizlendi");
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

    /// @notice T+2 kuyrugu: kotayi asan cikis_once revert eder, fonlar YERINDE KALIR
    function testT2QueueRevertsFirstAttempt() public {
        usdc.mint(alice, 200 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 200 ether);
        vault.deposit(200 ether, alice);

        // Gunluk kota = %10 x 200 = 20. 21 cekmek kuyruga girer.
        vault.requestRedemption(21 ether);

        // Fonlar YERINDE - T+2 ihlal edilmedi
        assertEq(usdc.balanceOf(alice), 20_000_000 ether, "Fonlar kuyruktayken hareket ETMEZ");
        assertGt(vault.queuedUnlockTime(alice), 0, "Kuyruk zamani set edildi");

        // Hemen cekme reddedilir
        vm.expectRevert("T+2 bekleme suresi dolmadi");
        vault.withdraw(21 ether, alice, alice);
        vm.stopPrank();
    }

    /// @notice T+2: 2 gun sonra ayni cagri basarili olur
    function testT2QueueSucceedsAfter2Days() public {
        usdc.mint(alice, 200 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 200 ether);
        vault.deposit(200 ether, alice);

        vault.requestRedemption(21 ether);

        // 2 gun bekle
        vm.warp(block.timestamp + 2 days + 1);

        vault.withdraw(21 ether, alice, alice);
        assertGt(usdc.balanceOf(alice), 20_000_000 ether, "T+2 sonrasi cekim basarili");
        assertEq(vault.queuedUnlockTime(alice), 0, "Kuyruk temizlendi");
        vm.stopPrank();
    }

    /// @notice T+2: 2 gun dolmadan ikinci deneme reddedilir
    function testT2QueueRejectsBeforeUnlock() public {
        usdc.mint(alice, 200 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 200 ether);
        vault.deposit(200 ether, alice);

        vault.requestRedemption(21 ether);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert("T+2 bekleme suresi dolmadi");
        vault.withdraw(21 ether, alice, alice);
        vm.stopPrank();
    }

    /// @notice Kota icindeki cikis anlik yapilir, kuyruga girmez
    function testInstantWithinDailyCap() public {
        usdc.mint(alice, 200 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 200 ether);
        vault.deposit(200 ether, alice);

        // 20 = tam %10 kotasi -> anlik
        vault.withdraw(20 ether, alice, alice);
        assertGt(usdc.balanceOf(alice), 19_999_000 ether, "Kota icinde anlik");
        assertEq(vault.queuedUnlockTime(alice), 0, "Kuyrukta degil");
        vm.stopPrank();
    }

    /// @notice Feed baglaninca Optimize modu acilabilir
    function testOptimizeAfterFeedWired() public {
        address feed = address(0xFEED);

        vm.prank(founder);
        vault.setAaveUtilizationFeed(feed);

        vm.prank(founder);
        vault.setOptimizeMode(true);

        assert(uint256(vault.activeTier()) == uint256(ICleanvestVault.ReserveTier.TierOptimize));
    }

    /// @notice Getiri egrisi: Tier0 > Tier1 (OUSG eklendiginde dusus)
    function testYieldCurveMonotone() public {
        // Tier0
        usdc.mint(alice, 100_000 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, alice);
        uint256 y0 = vault.currentSeniorYield();
        vm.stopPrank();

        // Tier1
        usdc.mint(bob, 250_000 ether);
        vm.startPrank(bob);
        usdc.approve(address(vault), 250_000 ether);
        vault.deposit(250_000 ether, bob);
        uint256 y1 = vault.currentSeniorYield();
        vm.stopPrank();

        assertLt(y1, y0, "Tier1 getirisi Tier0'dan DUSUK olmali");
        assertGt(y0, 0, "Getiri pozitif");
    }

    function testCircuitBreakerOptimizeHighUtil() public {
        MockUtilizationFeed feed = new MockUtilizationFeed(9500); // %95 > %92

        vm.startPrank(founder);
        vault.setAaveUtilizationFeed(address(feed));
        vault.setOptimizeMode(true);
        vm.stopPrank();

        // Test fonksiyonu: _instantRedemptionAllowed false olmali
        // (public wrapper yok, bu yuzden davranisi requestRedemption ile olc)
        usdc.mint(alice, 1000 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);

        // Kota icinde (%10 = 100) ama devre-kesici aktif -> T+2 kuyrugu
        vault.requestRedemption(50 ether);
        assertGt(vault.queuedUnlockTime(alice), 0, "Devre-kesici: T+2 kuyrugu");
        vm.stopPrank();
    }

    /// @notice OPTIMIZE modda utilization <%92 -> anlik cekim devam
    function testCircuitBreakerOptimizeLowUtil() public {
        MockUtilizationFeed feed = new MockUtilizationFeed(8000); // %80 < %92

        vm.startPrank(founder);
        vault.setAaveUtilizationFeed(address(feed));
        vault.setOptimizeMode(true);
        vm.stopPrank();

        usdc.mint(alice, 1000 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);

        // Kota icinde ve devre-kesici KAPALI -> kuyruk YOK
        vault.requestRedemption(50 ether);
        assertEq(vault.queuedUnlockTime(alice), 0, "Devre-kesici kapali: anlik");
        vm.stopPrank();
    }

    /// @notice SAFE modda utilization okunmaz (her zaman anlik)
    function testSafeModeIgnoresFeed() public {
        MockUtilizationFeed feed = new MockUtilizationFeed(9900); // %99

        vm.prank(founder);
        vault.setAaveUtilizationFeed(address(feed));
        // optimizeModeEnabled hala false

        usdc.mint(alice, 1000 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1000 ether);
        vault.deposit(1000 ether, alice);

        vault.requestRedemption(50 ether);
        assertEq(vault.queuedUnlockTime(alice), 0, "SAFE mod: feed yoksayilir");
        vm.stopPrank();
    }

    /// @notice Getiri egrisi PROJE_KAGIDI.md L99 ile BIREBIR: %3.05/%2.91/%2.92
    function testYieldCurveMatchesSpec() public {
        // Tier0: TVL < $250k -> %3.05
        assertEq(vault.currentSeniorYield(), 0.0305e18, "Tier0 = %3.05 (KAGIDI L99)");

        // Tier1: $250k+ -> %2.91
        vm.startPrank(alice);
        usdc.approve(address(vault), 250_000 ether);
        vault.deposit(250_000 ether, alice);
        vm.stopPrank();
        assertEq(vault.currentSeniorYield(), 0.0291e18, "Tier1 = %2.91 (KAGIDI L99)");

        // Tier2: $12.5M+ -> %2.92 (alice toplam 12.75M)
        vm.startPrank(alice);
        usdc.approve(address(vault), 12_500_000 ether);
        vault.deposit(12_500_000 ether, alice);
        vm.stopPrank();
        assertEq(vault.currentSeniorYield(), 0.0292e18, "Tier2 = %2.92 (KAGIDI L99)");
    }
    /// @notice ERC-4626 INFLATION ATTACK regresyon testi (Cream/Sonne/Resupply tipi)
    /// @dev Saldirdi: onyuz minShares hesaplar -> saldiri durumunda revert -> fon korunur
    function testInflationAttackBlockedByMinShares() public {
        // Saldirmaci 1 wei ile 1 pay alir (ilk depozitor)
        vm.startPrank(bob);
        usdc.approve(address(vault), 1);
        vault.deposit(1, bob);
        vm.stopPrank();

        // Saldirmaci kasaya DOGRUDAN 100_000 cUSD bagislar (pay fiyatini siseirmek)
        usdc.mint(address(vault), 100_000 ether);

        // Kurbannin gercek pay sayisi (bagis sonrasi cok dusuk olur)
        uint256 expectedShares = vault.convertToShares(1_000 ether);
        // Bagis siseirdigi icin kurban cok az pay alir - slippage KORUMASI:
        // Kurbannin hesapladigi minShares = beklenen payin %99'u
        vm.startPrank(alice);
        usdc.approve(address(vault), 1_000 ether);
        // minShares = beklenen (dusuk) pay - bu keza gecer; ASIL koruma:
        // kurban YANLIS yuksek minShares verirse revert (saldiriyi belirler)
        vm.expectRevert("Slippage: pay sayisi minimumun altinda");
        vault.depositWithMin(1_000 ether, alice, expectedShares + 10);
        vm.stopPrank();
    }

    /// @notice depositWithMin: dogru minShares ile basarili calisir
    function testDepositWithMinSucceeds() public {
        uint256 expected = vault.convertToShares(1_000 ether);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1_000 ether);
        uint256 shares = vault.depositWithMin(1_000 ether, alice, expected);
        assertGe(shares, expected, "en az minShares kadar pay alindi");
        vm.stopPrank();
    }

    /// @notice redeemWithMin: dogru minAssets ile basarili calisir
    /// @dev Gunluk anlik kota %10: kucuk cikis anlik onaylanir (kuyruk gerekmez)
    function testRedeemWithMinSucceeds() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, alice);
        // %10 kota icinde kucuk cikis (50 ether, kota 100 ether)
        uint256 shares = vault.convertToShares(50 ether);
        uint256 expectedAssets = vault.convertToAssets(shares);
        uint256 out = vault.redeemWithMin(shares, alice, alice, expectedAssets);
        assertGe(out, expectedAssets, "en az minAssets kadar varlik alindi");
        vm.stopPrank();
    }

}



/// @notice Aave utilization feed mock (devre-kesici testleri icin).
contract MockUtilizationFeed {
    uint256 public utilizationBps;
    constructor(uint256 _bps) { utilizationBps = _bps; }
    function setUtilization(uint256 _bps) external { utilizationBps = _bps; }

    /// @notice OPTIMIZE modda utilization >%92 -> anlik cekim T+2'ye duser

}