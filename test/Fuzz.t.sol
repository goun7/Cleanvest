// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/ListingGate.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";
import "../contracts/interfaces/ICleanvestSettlement.sol";
import "../contracts/interfaces/ICleanvestVault.sol";

/// @title FuzzTest - Invariant Tabanli Fuzz Testleri
/// @author Cleanvest
/// @dev Bulpyunit testlerin yakalayamadigi KENAR DURUMLARI yakalar.
///      Calistirma: forge test --match-contract FuzzTest
contract FuzzTest is Test {
    CleanvestSettlement settlement;
    CleanUSD cUSD;
    CleanFXVault vault;
    ListingGate gate;
    address founder = address(this);

    function setUp() public {
        cUSD = new CleanUSD();
        settlement = new CleanvestSettlement();
        vault = new CleanFXVault(address(cUSD));
        gate = new ListingGate();
    }

    // ============================================================
    // 1. ANTI-COLLUSION BOUND INVARIANTLARI
    // ============================================================

    /// @notice eps her zaman [EPS0=15, 500] araliginda OLMALI
    /// @dev Tekrarlama: her input icin sinirlar korunmali.
    function testFuzzEpsBounds(uint256 dQ, uint256 L) public view {
        uint256 eps = settlement.antiCollusionBound(dQ, L);

        // Alt sinir: en az taban (15 bps)
        assertGe(eps, 15, "eps >= 15 bps (taban)");
        // Ust sinir: en fazla %5 (500 bps)
        assertLe(eps, 500, "eps <= 500 bps (tavan)");
    }

    /// @notice L=0 iken her zaman EPS0 donmeli
    function testFuzzEpsZeroLiquidity(uint256 dQ) public view {
        assertEq(settlement.antiCollusionBound(dQ, 0), 15, "L=0 -> taban 15 bps");
    }

    /// @notice dQ=0 iken de taban 15 bps (kicker yok, 0'a dusmez)
    function testFuzzEpsZeroOrder(uint256 L) public view {
        assertEq(settlement.antiCollusionBound(0, L), 15, "dQ=0 -> taban 15 bps");
    }

    /// @notice eps, dQ arttikca MONOTONIK olarak artmali (ya ayni kalmali)
    /// @dev Bu, kucuk emirlerin cezalandirilmadigini garanti eder.
    function testFuzzEpsMonotoneInOrderSize(uint256 L, uint256 dQ1, uint256 dQ2) public view {
        (dQ1, dQ2) = dQ1 < dQ2 ? (dQ1, dQ2) : (dQ2, dQ1);
        uint256 eps1 = settlement.antiCollusionBound(dQ1, L);
        uint256 eps2 = settlement.antiCollusionBound(dQ2, L);
        assertGe(eps2, eps1, "eps(dQ2 >= dQ1) >= eps(dQ1) - monotone");
    }

    /// @notice Cok buyuk emirler tavanin (500) ustune cikamaz
    function testFuzzEpsMaxCap() public view {
        uint256 eps = settlement.antiCollusionBound(type(uint256).max, 1);
        assertEq(eps, 500, "Asiri buyuk emir -> 500 bps tavan");
    }

    // ============================================================
    // 2. GRADE FOR INVARIANTLARI
    // ============================================================

    /// @notice Grade'ler bantlarin disina cikamaz
    /// @dev S/A/B/C/D harfleri disinda bisey donemez.
    function testFuzzGradeInRange(uint256 score) public view {
        bytes1 grade = _gradeForPublic(score);
        bool valid = grade == bytes1("S") || grade == bytes1("A") || grade == bytes1("B")
            || grade == bytes1("C") || grade == bytes1("D");
        assertTrue(valid, "Grade S/A/B/C/D disinda gecerli degil");
    }

    /// @return oncelik 5=S (en iyi) ... 1=D. ASCII sirasi ile TERS oldugundan
    ///         dogrudan harf karsilastirilamaz (A=65 < B=66 ama A daha iyidir).
    function _gradePriority(bytes1 g) internal pure returns (uint8) {
        if (g == bytes1("S")) return 5;
        if (g == bytes1("A")) return 4;
        if (g == bytes1("B")) return 3;
        if (g == bytes1("C")) return 2;
        return 1; // D
    }

    function _gradeForPublic(uint256 score) internal pure returns (bytes1) {
        if (score >= 95) return bytes1("S");
        if (score >= 85) return bytes1("A");
        if (score >= 70) return bytes1("B");
        if (score >= 50) return bytes1("C");
        return bytes1("D");
    }

    /// @notice Grade MONOTONIK: yuksek skor -> en az ayni grade
    function testFuzzGradeMonotone(uint256 a, uint256 b) public view {
        uint256 low = a < b ? a : b;
        uint256 high = a < b ? b : a;
        vm.assume(low <= 100);
        high = bound(high, low, 100);
        bytes1 gl = _gradeForPublic(low);
        bytes1 gh = _gradeForPublic(high);
        assertGe(_gradePriority(gh), _gradePriority(gl), "yuksek skor >= dusuk skor grade");
    }

    // ============================================================
    // 3. JUNIOR COVERAGE INVARIANTI
    // ============================================================

    /// @notice Junior coverage HER zaman %3 (hard invariant, degismez)
    function testFuzzJuniorCoverageConstant(uint256) public view {
        assertEq(vault.juniorCoverageRatio(), 300, "Junior = %3 sabit");
    }

    /// @notice Redemption gate her zaman (%10 anlik, T+2)
    function testFuzzRedemptionGateConstant(uint256) public view {
        (uint256 cap, uint256 days_) = vault.redemptionGate();
        assertEq(cap, 1000, "Gunluk anlik kota %10");
        assertEq(days_, 2 days, "T+2 (2 gun = 172800 sn)");
    }

    // ============================================================
    // 4. MINT GATE INVARIANTI
    // ============================================================

    /// @notice Mint'ten sonra junior invariant KORUNMALI
    function testFuzzMintPreservesInvariant(uint256 seed, uint256 mintAmount) public {
        cUSD.seedJunior{value: 3_000 ether}(0);
        mintAmount = bound(mintAmount, 1, 50_000 ether);
        vm.assume(cUSD.canMint());

        uint256 supplyBefore = cUSD.totalSupply();
        if (supplyBefore + mintAmount > cUSD.tvlCap()) {
            // Tavani asarsa mint revert etmeli (gate)
            vm.expectRevert();
            cUSD.mint(address(1), mintAmount);
        } else {
            cUSD.mint(address(1), mintAmount);
            // Invariant: junior * 10000 >= tvl * 300
            assertGe(cUSD.juniorReserve() * 10000, cUSD.totalSupply() * 300, "Junior invariant korundu");
        }
    }

    receive() external payable {}
}
