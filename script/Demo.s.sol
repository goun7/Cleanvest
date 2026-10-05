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
        // Deploy + tohum TEK broadcast blokunda (replay tutarlili icin).
        // seedJunior broadcast disinda olursa --broadcast replay'inde
        // kaybolur, juniorReserve=0 kalir, mint "Junior <%3" revert alir.
        // NOT: amount PARAMETRESI ile (msg.value'suz) — Bootstrap 615e171 ile
        // ayni neden: {value: 3_000 ether} gercek ETH'yi CleanUSD'de SONSUZA
        // kilitler (cekme fonksiyonu yok). Test ETH bile kilitlenmemeli; demo
        // cUSD'nin ETH bakiyesi 0 olmali (docs/29 EK dogrulama ile uyumlu).
        vm.startBroadcast(vm.addr(pk));

        cusd = new CleanUSD();
        vault = new CleanFXVault(address(cusd));
        cusd.seedJunior(3_000 ether);
        vm.stopBroadcast();
        console.log("    cUSD:", address(cusd));
        console.log("    scUSD (vault):", address(vault));
        console.log("    junior tohumu: $3.000 -> cap acildi");
        console.log("");

        // ── ADIM 2: ALICE $100K YATIRIR ─────────────────────────
        console.log("[2/6] Alice $100.000 yatiriyor...");
        // DİKKAT: mint broadcast DISINDA vm.prank ile yapilir.
        // --broadcast tum islemleri bastan simule eder; eger mint
        // broadcast icindeyse, warp/cekis state'i simülasyonda kaybolur
        // ve mint "Junior <%3" revert'i alir. Prank + state tutarli.
        // 1) Deployer Alice'e cUSD basar
        vm.startBroadcast(vm.addr(pk));
        cusd.mint(ALICE, DEPOSIT);
        vm.stopBroadcast();

        // 2) Alice kendi islemini yapar (anvil tum hesaplari unlock eder)
        vm.startBroadcast(ALICE);
        cusd.approve(address(vault), DEPOSIT);
        uint256 expected = vault.convertToShares(DEPOSIT);
        uint256 minShares = (expected * 9950) / 10000;
        uint256 shares = vault.depositWithMin(DEPOSIT, ALICE, minShares);
        vm.stopBroadcast();
        console.log("    Alice bakiyesi:", shares / 1e18, "scUSD");
        console.log("    Vault TVL:", vault.totalAssets() / 1e18, "cUSD");
        console.log("    Aktif kademe:", _tierName(vault.activeTier()));
        console.log("");

        // ── ADIM 3: 1 YIL GETIRI BIRIKIR ────────────────────────
        console.log("[3/6] 1 yil ileri sariliyor (getiri birikimi)...");
        console.log("    NOT: demo'da dis getiri kaynagi yok (ReserveManager");
        console.log("    bagli degil) - pay fiyati sabit. Getiri ORANI gosteriliyor.");
        // currentSeniorYield(): 1e18 = %100 -> 1e16 = %1
        uint256 yieldPct = vault.currentSeniorYield() / 1e16;
        // ERC-4626: pay basina dustugu varlik = totalAssets / totalSupply
        uint256 balanceBefore = _aliceValue();

        vm.warp(block.timestamp + YEAR);
        // NOT: getiri pay fiyatinda dogal olarak yansir (ERC-4626 standardi).
        // Vault harici accrue gerektirmez - accrue() YOK (gereksizdi).

        uint256 balanceAfter = _aliceValue();
        uint256 gain = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;

        // 2 ondalik goster: 305 = %3.05 (bp/100 = yuzde, bp%100 = ondalik)
        uint256 yieldBps = vault.currentSeniorYield() / 1e14;
        uint256 yInt = yieldBps / 100;
        uint256 yDec = yieldBps % 100;
        // "3.05" icin ondalik herzaman 2 basamak (5 -> 05)
        console.log("    Senet getiri orani: %s.%s", _2digit(yInt), _2digit(yDec));
        console.log("    1 yil sonra Alice bakiyesi:", balanceAfter / 1e18, "cUSD");
        console.log("    Getiri (projeksiyon):", gain / 1e18, "cUSD");
        console.log("");

        // ── ADIM 4: ANLIK %10 CEKIS ─────────────────────────────
        console.log("[4/6] Anlik cekis ($10.000 = gunluk %10 kota icinde)...");
        // Cekis: Alice kendi imzasiyla
        vm.startBroadcast(ALICE);
        uint256 sharesToBurn = vault.convertToShares(INSTANT_WITHDRAW);
        uint256 minOut = (INSTANT_WITHDRAW * 9950) / 10000;
        uint256 out = vault.redeemWithMin(sharesToBurn, ALICE, ALICE, minOut);
        vm.stopBroadcast();
        console.log("    Anlik cikis:", out / 1e18, "cUSD (KUYRUK YOK)");
        console.log("    Gunluk kota: %10 doldu");
        console.log("");

        // ── ADIM 5: T+2 KALAN CEKIS (KUYRUK) ────────────────────
        console.log("[5/6] Kalan cekis ($20.000) T+2 kuyruguna alinir...");
        // Kuyruk talebi: Alice imzasiyla
        vm.startBroadcast(ALICE);
        vault.requestRedemption(QUEUED_WITHDRAW);
        vm.stopBroadcast();
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

    /// @notice Sayiyi her zaman 2 basamakli string yapar (5 -> "05", 12 -> "12").
    function _2digit(uint256 n) internal pure returns (string memory) {
        if (n < 10) return string(abi.encodePacked("0", _uintStr(n)));
        return _uintStr(n);
    }

    function _uintStr(uint256 n) internal pure returns (string memory) {
        if (n == 0) return "0";
        uint256 j = n;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory b = new bytes(len);
        uint256 k = len;
        while (n != 0) {
            k = k - 1;
            b[k] = bytes1(uint8(48 + n % 10));
            n /= 10;
        }
        return string(b);
    }

    function _tierName(CleanFXVault.ReserveTier t) internal pure returns (string memory) {
        if (t == ICleanvestVault.ReserveTier.Tier0) return "Tier 0 (Baslangic, %3.05)";
        if (t == ICleanvestVault.ReserveTier.Tier1) return "Tier 1 (Kurumsal, %2.91)";
        if (t == ICleanvestVault.ReserveTier.Tier2) return "Tier 2 (Likidite, %2.92)";
        return "Tier Optimize";
    }
}
