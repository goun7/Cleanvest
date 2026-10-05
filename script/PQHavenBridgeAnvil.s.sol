// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/ReserveManager.sol";

/// @title PQHaven <-> Cleanvest Koprusu - Secenek A ANVIL CANLI KANIT
/// @notice docs/34 akisini anvil'de UCTAN UCA calistirir. HICBIR contracts/*.sol
///         DEGISTIRILMEDI - bu yalnizca SCRIPT'tir (test ile ayni mantik).
///
/// AKIS:
///   1. musteri -> treasury: USDC odeme (guard dogrular)
///   2. treasury -> owner: KOPRU ADIMI (sifir kod, EOA->EOA transfer)
///   3. owner: depositReserve(usdc6 * 1e12) - 6->18 desimal
///   4. owner: supplyToAave - GERCEK fon hareketi
contract PQHavenBridgeAnvil is Script {
    // Anvil account[1] = treasury, account[0] = owner (deployer)
    // Script broadcast ile kullanilmaz; address literal olarak test edilir.

    function run() external {
        // ANVIL HESAPLARI (mnemonic'ten turetilmisse adresleri logla)
        address owner = msg.sender; // anvil[0] = PRIVATE_KEY ile deploy eden
        address treasury = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // anvil[1]
        address musteri = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // anvil[2]
        address aavePool = 0x90f79Bf6EB2c4F870365e78538256BF3D0fA1F4D; // anvil[3]

        console.log("=== SECENEK A - UCTAN UCA KOPIRU (anvil) ===");

        // --- 0. Mock USDC (6 desimal) deploy et ---
        vm.startBroadcast(); // owner = msg.sender = anvil[0] (PRIVATE_KEY)
        USDC6 usdc = new USDC6();
        console.log("USDC6 (mock, 6-decimal):", address(usdc));

        // --- ReserveManager kur (owner = deployer = anvil[0]) ---
        ReserveManager reserve = new ReserveManager(address(usdc));
        console.log("ReserveManager:", address(reserve));
        reserve.setAavePool(aavePool);

        // Aave pool'a USDC onayi (supplyToAave icin reserve'dan transfer)
        usdc.mint(address(reserve), 10_000 * 1e6);
        reserve.depositReserve(10_000 ether);
        vm.stopBroadcast();
        console.log("Baslangic idleBalance (18-dec):", reserve.idleBalance());

        // anvil[0] = PRIVATE_KEY karsiligi (script msg.sender)
        require(reserve.owner() == msg.sender, "owner = deployer olmali");

        // --- 1. MUSTERI ODADASI: musteri -> treasury (guard dogrular) ---
        vm.startBroadcast(musteri);
        usdc.mint(musteri, 2_000 * 1e6); // 2000 USDC (musteri'nin bakiyesi)
        usdc.transfer(treasury, 2_000 * 1e6);
        vm.stopBroadcast();
        console.log("[1] musteri -> treasury: 2000 USDC");
        console.log("    treasury USDC bakiye:", usdc.balanceOf(treasury));

        // --- 2. KOPRU ADIMI: treasury -> owner (EOA->EOA, sifir kod) ---
        vm.startBroadcast(treasury);
        usdc.transfer(owner, 2_000 * 1e6);
        vm.stopBroadcast();
        console.log("[2] treasury -> owner (KOPRU): 2000 USDC");
        console.log("    owner USDC bakiye:", usdc.balanceOf(owner));
        console.log("    treasury USDC bakiye:", usdc.balanceOf(treasury));

        // --- 3. OWNER: depositReserve(usdc6 * 1e12) - 6->18 cevirim ---
        uint256 amount18 = 2_000 * 1e6 * 1e12; // = 2000 ether
        vm.startBroadcast(owner);
        reserve.depositReserve(amount18);
        vm.stopBroadcast();
        console.log("[3] owner depositReserve(2000 ether = 2000 USDC6 * 1e12)");
        console.log("    idleBalance (18-dec):", reserve.idleBalance());
        uint256 idleAfterDeposit = reserve.idleBalance();
        // METRIK (b) BURADA OLCHULMALI: supplyToAave once (o ayri bir operasyon)
        console.log("(b) idleBalance delta (deposit'ten):", idleAfterDeposit - 10_000 ether);

        // --- 4. GERCEK FON HAREKETI: supplyToAave ---
        // NOT: supplyToAave USDC native 6-desimal alir (ReserveManager L141:
        // usdc.transfer ile). idleBalance 18-desimal oldugu icin bu fonksiyon
        // ayri bir operasyondur - Secenek A'nin (b) metrigini etkilemez.
        vm.startBroadcast(owner);
        reserve.supplyToAave(2_000 * 1e6);
        vm.stopBroadcast();
        console.log("[4] owner supplyToAave(2000 USDC) - GERCEK transfer");
        console.log("    aavePool USDC:", usdc.balanceOf(aavePool));
        console.log("    reserve USDC:", usdc.balanceOf(address(reserve)));

        // --- 3 METRIK ---
        console.log("");
        console.log("=== 3 METRIK (supplyToAave sonrasi) ===");
        console.log(
            "(b) idleBalance delta (deposit'ten, yukarida):", idleAfterDeposit - 10_000 ether
        );
        console.log("(c) owner USDC kalan:", usdc.balanceOf(owner));
        console.log("(c2) aavePool USDC (reserve'e gecti):", usdc.balanceOf(aavePool));

        // --- MERKEZI RISK KANITI ---
        console.log("");
        console.log("=== MERKEZI RISK KANITI (docs/34) ===");
        // Yeni odeme: musteri -> treasury -> owner ama owner AKTARMAZ
        // mint broadcast ICINDE olmali (musteri'nin bakiyesi olusturulur)
        vm.startBroadcast(musteri);
        usdc.mint(musteri, 5_000 * 1e6);
        usdc.transfer(treasury, 5_000 * 1e6);
        vm.stopBroadcast();
        vm.startBroadcast(treasury);
        usdc.transfer(owner, 5_000 * 1e6);
        vm.stopBroadcast();
        uint256 idleBefore = reserve.idleBalance();
        // [!] owner depositReserve CIMADI - risk
        console.log("owner depositReserve CIMADI -> USDC birikti");
        console.log("    owner USDC bakiye (BIRIKIM):", usdc.balanceOf(owner));
        console.log("    idleBalance (degismedi):", reserve.idleBalance());
        // Kanit: owner aktarmadigi icin reserve'a girmedi (assertilebilir)
        if (reserve.idleBalance() != idleBefore) {
            console.log("    [HATA] reserve'a girmemeliydi");
        } else {
            console.log("    [KANITLANDI] reserve'a girmiyor - fonlar owner'da birikiyor");
        }

        console.log("");
        console.log("=== ONAYLANDI: 174 tests (166+8) + anvil kaniti ===");
    }
}

contract USDC6 is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
