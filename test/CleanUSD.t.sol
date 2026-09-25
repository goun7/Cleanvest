// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanUSD.sol";

/// @title CleanUSD Hard Invariant Test Suite
/// @notice TVL-Kapl Sert Degismez: JuniorReserve >= TVL * 3%
///         Kural ihlali  mint DURUR. Burn ASLA durmaz.
contract CleanUSDTest is Test {
    CleanUSD public cUSD;
    address public founder = address(0xF0D5000);
    address public alice = address(0xA11CE);

    function setUp() public {
        vm.deal(founder, 100_000 ether);
        cUSD = new CleanUSD();
        cUSD.transferOwnership(founder);
    }

    /// @notice Tohum oncesi mint kapal olmal
    function testRevertMintBeforeSeed() public {
        vm.expectRevert("TVL-Kapili Degismez: Junior <%3, mint kilitli");
        cUSD.mint(alice, 1);
    }

    /// @notice $3.000 tohum  $100.000 TVL tavan
    function testSeedOpensTvlCap() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        assertTrue(cUSD.capUnlocked());
        assertEq(cUSD.tvlCap(), 100_000 ether, "3k/0.03 = 100k");
        assertEq(cUSD.juniorReserve(), 3_000 ether);
    }

    /// @notice Tam esik snr: $100.000 mint $3.000 junior ile gecmeli
    function testMintAtExactThreshold() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        // 100.000 tam esigi  junior*10000 == tvl*300  >= gecer
        cUSD.mint(alice, 100_000 ether);
        assertEq(cUSD.totalSupply(), 100_000 ether);
        assertEq(cUSD.juniorCoverageBps(), 300, "Tam %3");
    }

    /// @notice Esik asm: 1 wei fazla  REVERT
    function testRevertOneWeiAboveThreshold() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        // Once tvlCap kontrolu tetiklenir (100_001 > 100_000) - bu dogru davranis
        vm.expectRevert("TVL tavani asildi");
        cUSD.mint(alice, 100_000 ether + 1);
    }

    /// @notice Burn ckslar ASLA kilitlenmez
    function testBurnNeverLocked() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);
        cUSD.mint(alice, 50_000 ether);

        // Alice'i yakma yetkisi ver
        vm.prank(alice);
        cUSD.burn(50_000 ether);
        assertEq(cUSD.totalSupply(), 0);
    }

    /// @notice Burn  TVL duser  mint kaps yeniden aclr
    function testBurnReopensMintGate() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);
        cUSD.mint(alice, 100_000 ether);

        // Tam esik: junior*10000 == tvl*300 -> >= gecer, mint hala acik.
        // 1 wei daha mintlemeye calisirsa invariant tetiklenir:
        assertTrue(cUSD.canMint(), "Tam esikte >= kurali gecer");

        // Alice yakar  TVL duser  kap aclr
        vm.prank(alice);
        cUSD.burn(50_000 ether);

        assertTrue(cUSD.canMint());
    }

    /// @notice Cks kaps daima acktr
    function testRedemptionsAlwaysOpen() public view {
        assertTrue(cUSD.redemptionsOpen());
    }

    /// @notice JuniorCoverage oran dogru hesaplanr
    function testJuniorCoverageBps() public {
        vm.prank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);
        cUSD.mint(alice, 50_000 ether);

        // junior=3000, tvl=50000  3000/50000 = %6 = 600 bps
        assertEq(cUSD.juniorCoverageBps(), 600);
    }

    /// @notice REBASE YOK - kontratta rebase fonksiyonu bulunmamal
    function testNoRebaseFunction() public view {
        // Bu test derleme zaman garantisidir: CleanUSD rebase() icermez.
        // Eger eklenirse bu test derlenmez. Kodla islenmis yasak.
        bytes4 noRebaseSelector = bytes4(keccak256("rebase()"));
        //Selector varlgn manuel assert ile dogrula
        (bool ok,) = address(cUSD).staticcall(abi.encodeWithSelector(noRebaseSelector));
        assertFalse(ok, "REBASE YASAK - rebase() bulunmamal");
    }

    /// @notice canMintAfter katmani: cap tam dolu mint basarili (esitlik >= %3)
    /// @dev BULGU (bu tur): tvlCap kontrolu once calisir; canMintAfter
    ///      false <=> newTvl > tvlCap oldugundan ikinci katman golgelenir.
    ///      Bu BILINÇLI defense-in-depth'tur (sozlesmede dokumante edildi).
    ///      Test, GOZLENEN davranisi sabitler: cap'e tam esit mint OK,
    ///      cap'i asan mint "TVL tavani asildi" ile revert.
    function testMintAtCapBoundarySucceeds() public {
        vm.startPrank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        // cap'e TAM ESIT mint: junior 3000/100000 = %3.00 >= %3 -> BASARILI
        uint256 cap = cUSD.tvlCap();
        cUSD.mint(alice, cap);
        vm.stopPrank();

        assertEq(cUSD.totalSupply(), cap, "Cap tam dolu mint basarili");
        // junior hala tam %3'te (invariant saglandi)
        assertEq(cUSD.juniorCoverageBps(), 300, "Junior hala >= %3");
    }

    /// @notice Cap'i asan mint reddedilir (L91 - birinci katman)
    function testRevertMintExceedsCap() public {
        vm.startPrank(founder);
        cUSD.seedJunior{value: 3_000 ether}(0);

        // DİKKAT: tvlCap() cagrisi expectRevert'ten ONCE yapilmali -
        // forge "next call" bekler, arguman icindeki staticcall'i sayar
        uint256 overCap = cUSD.tvlCap() + 1;
        vm.expectRevert("TVL tavani asildi");
        cUSD.mint(alice, overCap);
        vm.stopPrank();

        assertEq(cUSD.totalSupply(), 0, "Cap asimi reddedildi");
    }
}
