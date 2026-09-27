// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";

/// @title Bootstrap - Likidite Tohumlama (deploy sonrasi tek adim)
/// @author Cleanvest
/// @notice Deploy sonrasi calistirilir: junior havuzunu besler, TVL
///         tavanini acar ve hazirlik durumunu dogrular.
///
/// @dev KULLANIM (anvil):
///      export PRIVATE_KEY=0xac09...
///      export CUSD_ADDR=<deploy edilen CleanUSD adresi>
///      forge script script/Bootstrap.s.sol --rpc-url $RPC --broadcast
///
///      ONEMLI: seedJunior SADECE CleanUSD sahibi (deployer) calistirabilir.
///      Deploy ile ayni anahtarla calistirilmalidir.
///
///      TOHUM MATEMATIGI (KAGIT ile birebir):
///        $3.000 tohum / %3 = $100.000 TVL tavan
///        juniorCoverageBps() = 300 (tam %3.00)
///
///      ⚠️ TOHUM YONTEMİ — amount PARAMETRESI (gercek ETH DEGIL):
///        seedJunior payable'dir ama CleanUSD'de ETH cekme fonksiyonu YOK.
///        Gercek ETH gonderilirse (msg.value > 0) SONSUZA KILITLENIR. Bu
///        yuzden amount parametresi (msg.value = 0) kullanilir: juniorReserve
///        accounting olarak artar, tvlCap dogru acilir, ETH kilitlenmez.
///        GERCEK $3.000 ReserveManager'a aktarilmalidir (orada withdrawReserve
///        var) — bkz. docs/29_INSAN_KARARLARI.md KARAR 1 + deploy rehberi ADIM 3.
contract Bootstrap is Script {
    /// @notice Tohum miktari (wei). $3.000 = 3_000 ether (18 decimals).
    /// @dev amount parametresi olarak gonderilir (msg.value DEGIL) — ETH kilitlenmez.
    uint256 constant SEED = 3_000 ether;

    /// @notice Beklenen TVL tavani: 3_000 / 0.03 = 100_000
    /// @dev Bu tavan KALICIDIR — yalnizca ilk tohumda belirlenir, sonra
    ///      hicbir fonksiyon degistiremez. Daha buyuk tavan icin SEED'i
    ///      artir (tavan = SEED * 33.3).
    uint256 constant EXPECTED_CAP = 100_000 ether;

    function run() external {
        address cusdAddr = vm.envAddress("CUSD_ADDR");
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        require(pk != 0, "PRIVATE_KEY zorunlu");

        CleanUSD cusd = CleanUSD(cusdAddr);

        vm.startBroadcast(pk);

        // 1. Tohum: amount PARAMETRESI (msg.value'suz).
        // NEDEN: gercek ETH (msg.value > 0) CleanUSD'de SONSUZA KILITLENIR
        // (cekme fonksiyonu yok). amount parametresi juniorReserve'i
        // accounting olarak artirir: tvlCap dogru acilir, ETH guvende.
        // GERCEK $3.000 ayrica ReserveManager'a (withdrawReserve ile yonetilir).
        cusd.seedJunior(SEED);

        vm.stopBroadcast();

        // 2. Dogrulama (broadcast disinda, view calls)
        _verify(cusd);
    }

    /// @notice Tohum sonrasi hazirlik durumunu kanitlar.
    function _verify(CleanUSD cusd) internal view {
        uint256 junior = cusd.juniorReserve();
        uint256 cap = cusd.tvlCap();
        uint256 coverage = cusd.juniorCoverageBps();
        bool canMint = cusd.canMint();

        console.log("=== BOOTSTRAP DOGRULAMA ===");
        console.log("juniorReserve:", junior);
        console.log("tvlCap:       ", cap);
        console.log("coverageBps:  ", coverage);
        console.log("canMint:      ", canMint);

        // INARIANT'lar (KAGIT ile birebir)
        require(junior == SEED, "junior havuzu tohum kadar olmali");
        require(cap == EXPECTED_CAP, "cap 100k olmali (3k / 0.03)");
        require(coverage >= 300, "coverage >= %3 (300 bps) olmali");
        require(canMint, "mint kapisi ACIK olmali (junior >= %3)");

        console.log("=== HAZIR: mint acik, cap $100k, junior %3 ===");
    }
}
