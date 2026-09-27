// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/RiskTransparency.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";

/// @title RiskTransparency Testleri
/// @notice Akademik dayanak: Bundi 2026 (CBT/ESORICS) "disclosure" onerisi.
///         Makale: "standartlastirilmis kayiplar, mevcut sermaye tamponlari
///         ve kuyruk kapsamini" yayimlayin. Bu testler aciklamanin
///         KOD ILE BIREBIR oldugunu kanitlar.
contract RiskTransparencyTest is Test {
    CleanUSD cusd;
    CleanFXVault vault;

    function setUp() public {
        cusd = new CleanUSD();
        vault = new CleanFXVault(address(cusd));
        // Junior tohum: $3.000 -> $100K cap (standart lansman)
        cusd.seedJunior{value: 3_000 ether}(0);
        // Alice $100K yatirir (Tier 0)
        cusd.mint(address(this), 100_000 ether);
        cusd.approve(address(vault), 100_000 ether);
        vault.deposit(100_000 ether, address(this));
    }

    /// @notice Junior tampon profili dogru olmali (makale: "capital buffer")
    function testProfileJuniorBuffer() public view {
        RiskTransparency.RiskProfile memory p =
            RiskTransparency.profile(address(vault), address(0));

        // $3.000 junior / $100.000 TVL = %3.0 = 300 bps
        assertEq(p.juniorBufferBps, 300, "Junior tampon %3 olmali");
        assertEq(p.juniorBufferMinBps, 300, "Minimum eik %3");
        assertTrue(p.juniorBufferAdequate, "Tampon yeterli (tam esik)");
    }

    /// @notice Likidite aciklamasi (makale: redemption terms)
    function testProfileLiquidityTerms() public view {
        RiskTransparency.RiskProfile memory p =
            RiskTransparency.profile(address(vault), address(0));

        assertEq(p.dailyInstantCapBps, 1000, "Anlik cikis %10");
        assertEq(p.t2SettleSeconds, 2 days, "T+2 bekleme");
    }

    /// @notice Sifir TVL'de tampon max olmali (bolme sifir korumasi)
    function testProfileZeroTvl() public {
        CleanUSD c2 = new CleanUSD();
        CleanFXVault v2 = new CleanFXVault(address(c2));

        RiskTransparency.RiskProfile memory p =
            RiskTransparency.profile(address(v2), address(0));

        assertEq(p.juniorBufferBps, type(uint256).max, "Sifir TVL -> max (guvenli)");
        assertTrue(p.juniorBufferAdequate, "Max tampon yeterli");
    }

    /// @notice Optimize modu aciklandigi gibi gosterilmeli (reserve bagli)
    function testProfileOptimizeFlag() public {
        // ReserveManager bagli degilse optimize false gosterilir
        RiskTransparency.RiskProfile memory p =
            RiskTransparency.profile(address(vault), address(0));
        assertFalse(p.optimizeModeEnabled, "Reserve yoksa optimize false");
        assertEq(p.utilizationCircuitBreakerBps, 0, "Reserve yoksa CB gosterilmez");
    }

    /// @notice Insan-okur aciklama dogru format vermeli
    function testDescribeFormat() public view {
        RiskTransparency.RiskProfile memory p =
            RiskTransparency.profile(address(vault), address(0));
        string memory desc = RiskTransparency.describe(p);

        // "junior %3.0 / %3.0 | anlik %10.0 | T+2 | CB %0.0"
        // (CB 0 cunku reserve bagli degil)
        assertGt(bytes(desc).length, 20, "Aciklama uretilmeli");
        assertTrue(_contains(desc, "junior"), "junior anahtari olmali");
        assertTrue(_contains(desc, "anlik"), "anlik anahtari olmali");
    }

    /// @notice Yardimci: substring kontrolu
    function _contains(string memory hay, string memory needle) private pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length == 0) return true;
        if (h.length < n.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool match_ = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) { match_ = false; break; }
            }
            if (match_) return true;
        }
        return false;
    }
}
