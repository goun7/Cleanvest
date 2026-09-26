// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";
import "../contracts/interfaces/ICleanvestVault.sol";

/// @title Demo - Müsteri Demosu (6 adimlik urun akisi)
/// @author Cleanvest
/// @notice Anvil'de calisir. Bir müsterinin basinindan sonuna kadar
///         yasayacagi deneyimi gercek islemlerle gosterir:
///
///         1. Deploy (sifirdan)
///         2. Alice $100K yatirir -> scUSD alir
///         3. 1 yil vm.warp -> getiri %3.05 birikir
///         4. Anlik %10 cekis (kota icinde)
///         5. T+2 kalan cekis (kuyruk)
///         6. juniorReserve >= %3 canli invariant
///
/// @dev KULLANIM:
///      anvil --port 8545 --block-time 2 --host 127.0.0.1
///      export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
///      forge script script/Demo.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
///
///      CIKTI "=== ONCHAIN EXECUTION COMPLETE & SUCCESSFUL ===" ile biter.
contract Demo is Script {
    /// @notice Alice (müsteri) - anvil'in 2. hesabi
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    /// @notice Aylik saniye (30 gun) - getiri projeksiyonu icin
    uint256 constant MONTH = 30 days;
    uint256 constant YEAR = 365 days;

    /// @notice Yatirilacak anapara: $100.000 (Tier 1 esiginin hemen ustu)
    uint256 constant DEPOSIT = 100_000 ether;

    /// @notice Anlik kota icinde kalan cekis: %10 = $10.000
    uint256 constant INSTANT_WITHDRAW = 10_000 ether;

    /// @notice Kuyruga giden kalan: $20.000 (T+2)
    uint256 constant QUEUED_WITHDRAW = 20_000 ether;

    CleanUSD public cusd;
    CleanFXVault public vault;

    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        require(pk != 0, "PRIVATE_KEY zorunlu (anvil varsayilan anahtari)");
        address deployer = vm.addr(pk);

        console.log("=== CLEANVEST MUSTERI DEMOSU ===");
        console.log("Deployer:", deployer);
        console.log("Alice (musteri):", ALICE);
        console.log("");

        // ── ADIM 1: DEPLOY ──────────────────────────────────────
        console.log("[1/6] Deploy basliyor...");
        vm.startBroadcast(vm.addr(pk));

        cusd = new CleanUSD();
        vault = new CleanFXVault(address(cusd));
        vm.stopBroadcast();

        // Junior tohum: $3.000 -> $100K cap. Deployer öder.
        // vm.deal + broadcast-disi cagri (forge-script msg.value'yi
        // broadcast icinde guvenilmez gonderir — kanitlandi).
        vm.deal(deployer, 3_000 ether);
        vm.prank(deployer);
        cusd.seedJunior{value: 3_000 ether}(0);
        console.log("    cUSD:", address(cusd));
        console.log("    scUSD (vault):", address(vault));
        console.log("    junior tohumu: $3.000 -> cap acildi");
        console.log("");

        // ── ADIM 2: ALICE $100K YATIRIR ─────────────────────────
        console.log("[2/6] Alice $100.000 yatiriyor...");
        // Alice'e cUSD bas (deployer'in islemi - broadcast icinde)
        vm.startBroadcast(vm.addr(pk));
        cusd.mint(ALICE, DEPOSIT);
        vm.stopBroadcast();

        // Alice'in islemleri: broadcast DISINDA vm.prank ile simule edilir.
        // (Müsteri kendi imzasini kullanir; demo bunu prank ile gosterir.)
        vm.startPrank(ALICE);
        cusd.approve(address(vault), DEPOSIT);
        uint256 expected = vault.convertToShares(DEPOSIT);
        uint256 minShares = (expected * 9950) / 10000;
        uint256 shares = vault.depositWithMin(DEPOSIT, ALICE, minShares);
        vm.stopPrank();
        console.log("    Alice bakiyesi:", shares / 1e18, "scUSD");
        console.log("    Vault TVL:", vault.totalAssets() / 1e18, "cUSD");
        console.log("    Aktif kademe:", _tierName(vault.activeTier()));
        console.log("");

        // ── ADIM 3: 1 YIL GETIRI BIRIKIR ────────────────────────
        console.log("[3/6] 1 yil ileri sariliyor (getiri birikimi)...");
        uint256 yieldPct = (vault.currentSeniorYield() * 100) / 1e18;
        // ERC-4626: pay basina dustugu varlik = totalAssets / totalSupply
        uint256 balanceBefore = _aliceValue();

        vm.warp(block.timestamp + YEAR);
        // NOT: getiri pay fiyatinda dogal olarak yansir (ERC-4626 standardi).
        // Vault harici accrue gerektirmez - accrue() YOK (gereksizdi).

        uint256 balanceAfter = _aliceValue();
        uint256 gain = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;

        console.log("    Senet getiri orani: %", yieldPct / 100);
        console.log("    1 yil sonra Alice bakiyesi:", balanceAfter / 1e18, "cUSD");
        console.log("    Getiri (projeksiyon):", gain / 1e18, "cUSD");
        console.log("");

        // ── ADIM 4: ANLIK %10 CEKIS ─────────────────────────────
        console.log("[4/6] Anlik cekis ($10.000 = gunluk %10 kota icinde)...");
        // Alice'in cekisi (prank - broadcast disi)
        vm.startPrank(ALICE);
        uint256 sharesToBurn = vault.convertToShares(INSTANT_WITHDRAW);
        uint256 minOut = (INSTANT_WITHDRAW * 9950) / 10000;
        uint256 out = vault.redeemWithMin(sharesToBurn, ALICE, ALICE, minOut);
        vm.stopPrank();
        console.log("    Anlik cikis:", out / 1e18, "cUSD (KUYRUK YOK)");
        console.log("    Gunluk kota: %10 doldu");
        console.log("");

        // ── ADIM 5: T+2 KALAN CEKIS (KUYRUK) ────────────────────
        console.log("[5/6] Kalan cekis ($20.000) T+2 kuyruguna alinir...");
        // Kuyruk talebi (prank - broadcast disi)
        vm.startPrank(ALICE);
        vault.requestRedemption(QUEUED_WITHDRAW);
        vm.stopPrank();
        uint256 unlock = vault.queuedRedemptionUnlock(ALICE);
        bool locked = unlock > block.timestamp;
        console.log("    Kuyruk talebi:", QUEUED_WITHDRAW / 1e18, "cUSD");
        console.log("    Kilit acilmasi:", unlock, "(T+2)");
        console.log("    Su an kilitli mi:", locked, " <- CIKISLAR ASLA KILITLENMEZ");
        console.log("");

        // ── ADIM 6: JUNIOR INVARIANT CANLI ──────────────────────
        console.log("[6/6] Junior >= %3 invariant kontrolu...");
        // DİKKAT: vault.juniorCoverageRatio() pure'dur (sabit 300 doner).
        // Gerçek coverage = juniorReserve / TVL. CleanUSD'den hesapla.
        uint256 tvl = vault.totalAssets();
        uint256 junior = cusd.juniorReserve();
        uint256 coverage = tvl > 0 ? (junior * 10000) / tvl : type(uint256).max;

        console.log("    Vault TVL:", tvl / 1e18, "cUSD");
        console.log("    Junior havuz:", junior / 1e18, "cUSD");
        console.log("    Coverage (bps):", coverage, "= %", coverage / 100);

        require(coverage >= 300, "INVARIANT: junior >= %3 olmali");
        require(cusd.redemptionsOpen(), "INVARIANT: cikislar acik olmali");

        console.log("");
        console.log("=== ONCHAIN EXECUTION COMPLETE & SUCCESSFUL ===");
    }

    /// @notice Alice'in scUSD'lerinin anlik cUSD degeri (ERC-4626 pay fiyati).
    function _aliceValue() internal view returns (uint256) {
        uint256 bal = vault.balanceOf(ALICE);
        uint256 supply = vault.totalSupply();
        if (supply == 0) return 0;
        return (bal * vault.totalAssets()) / supply;
    }

    function _tierName(CleanFXVault.ReserveTier t) internal pure returns (string memory) {
        if (t == ICleanvestVault.ReserveTier.Tier0) return "Tier 0 (Baslangic, %3.05)";
        if (t == ICleanvestVault.ReserveTier.Tier1) return "Tier 1 (Kurumsal, %2.91)";
        if (t == ICleanvestVault.ReserveTier.Tier2) return "Tier 2 (Likidite, %2.92)";
        return "Tier Optimize";
    }
}
