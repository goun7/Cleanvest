// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";
import "../contracts/ReserveManager.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/ListingGate.sol";
import "../contracts/UniswapProxy.sol";
import "../contracts/ReferralLedger.sol";

/// @title Deploy - Cleanvest Tam Stack Deployment
/// @author Cleanvest
/// @notice 7 sozlesmeyi sirayla deploy eder ve birbirine baglar.
/// @dev GUVENLIK: canli aglarda (chainId != 31337) PRIVATE_KEY ZORUNLUDUR ve
///      anvil'in herkesçe bilinen test anahtarı REDDEDILIR. Canli deploy
///      yalnizca acik bir insan onayi (DEPLOY_CONFIRM) ile calisir.
///
/// ## Kullanim
///
/// ### Yerel anvil (test, anahtar GEREKMEZ)
/// ```bash
/// forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
/// ```
///
/// ### Dry-run (gas tahmini; broadcast YOK, anahtar GEREKMEZ)
/// ```bash
/// forge script script/Deploy.s.sol:Deploy
/// ```
///
/// ### Canli ag (PRIVATE_KEY + onay ZORUNLU)
/// ```bash
/// export PRIVATE_KEY=0x...
/// export RPC_URL=https://mainnet.base.org
/// export DEPLOY_CONFIRM=yes
/// forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL \
///     --private-key $PRIVATE_KEY --broadcast --verify
/// ```
library DeploymentConfig {
    /// @notice Production adresleri. Deployment sirasinda ENV'den alinir.
    /// @dev Bunlar ORNEKLEME amacllidir; gercek deploy'da .env dogrulanmali.
    struct Config {
        address usdc; // Base USDC
        address aavePool; // Aave V3 Pool (Base)
        address aavePrimePool; // Aave Prime Pool
        address chainlinkFeed; // Chainlink USDC/USD feed
        address uniswapRouter; // Uniswap V3 SwapRouter
        address cleanAuditOracle; // CleanAudit motor adresi (off-chain imzaci)
    }
}

contract Deploy is Script {
    /// @notice Deploy edilen tum sozlesmeler.
    struct Deployed {
        CleanUSD cUSD;
        CleanFXVault vault;
        ReserveManager reserve;
        CleanvestSettlement settlement;
        ListingGate gate;
        UniswapProxy proxy;
        ReferralLedger referral;
    }

    Deployed public deployed;
    DeploymentConfig.Config public cfg;

    /// @notice Anvil'in herkesçe bilinen test anahtari (account #0).
    /// @dev BU ANAHTAR CANLI AGDA ASLA KULLANILAMAZ — guard reddeder.
    uint256 internal constant ANVIL_TEST_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    /// @notice Yerel test aglarinin chainId'si (anvil ve hardhat).
    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    /// @notice Mevcut zincir canli bir ag mi? (chainId != 31337)
    bool public isLiveNetwork;

    function run() external {
        uint256 chainId = block.chainid;
        isLiveNetwork = chainId != LOCAL_CHAIN_ID;

        // Tum adresler ENV'den okunur - UYDURMA ADRES KULLANILMAZ
        cfg = DeploymentConfig.Config({
            usdc: vm.envOr("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913), // Base USDC
            aavePool: vm.envOr("AAVE_POOL", address(0)),
            aavePrimePool: vm.envOr("AAVE_PRIME_POOL", address(0)),
            chainlinkFeed: vm.envOr("CHAINLINK_FEED", address(0)),
            uniswapRouter: vm.envOr("UNISWAP_ROUTER", address(0)),
            cleanAuditOracle: vm.envOr("CLEANAUDIT_ORACLE", address(0))
        });

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));

        // ============================================================
        // MAINNET GUARD — insan karari olmadan canli deploy YASAK
        // ============================================================
        if (isLiveNetwork) {
            require(pk != 0, "CANLI AG: PRIVATE_KEY ZORUNLU (deploy reddedildi)");
            require(
                pk != ANVIL_TEST_KEY,
                "CANLI AG: anvil test anahtari YASAK (herkesin bildigi anahtar)"
            );
            require(
                keccak256(bytes(vm.envOr("DEPLOY_CONFIRM", string("")))) == keccak256(bytes("yes")),
                "CANLI AG: DEPLOY_CONFIRM=yes gerekiyor (insan onayi)"
            );
            console.log("=== CANLI DEPLOY (insan onayli) ===");
            console.log("chainId:", chainId);
            vm.startBroadcast(pk);
        } else {
            // Yerel anvil: anahtar yoksa anvil'in varsayilan test anahtari
            uint256 key = pk != 0 ? pk : ANVIL_TEST_KEY;
            if (pk == 0) {
                console.log("PRIVATE_KEY yok - anvil test anahtari kullaniliyor (SADECE yerel)");
            }
            vm.startBroadcast(key);
        }

        console.log("=== Cleanvest Deployment basliyor ===");
        console.log("chainId:", chainId);

        // Gas olcumu: her kontrat icin deploy gazini olc
        uint256 gasBefore;
        uint256 totalDeployGas;

        // 1. CleanUSD (sabit $1.00, REBASE YOK)
        gasBefore = gasleft();
        deployed.cUSD = new CleanUSD();
        totalDeployGas += _deployGas("CleanUSD", gasBefore);

        // 2. CleanFXVault (asset = cUSD)
        gasBefore = gasleft();
        deployed.vault = new CleanFXVault(address(deployed.cUSD));
        totalDeployGas += _deployGas("CleanFXVault", gasBefore);

        // 3. ReserveManager (Aave katmani)
        gasBefore = gasleft();
        deployed.reserve = new ReserveManager(cfg.usdc);
        totalDeployGas += _deployGas("ReserveManager", gasBefore);
        if (cfg.aavePool != address(0)) deployed.reserve.setAavePool(cfg.aavePool);
        if (cfg.aavePrimePool != address(0)) deployed.reserve.setAavePrimePool(cfg.aavePrimePool);
        if (cfg.chainlinkFeed != address(0)) {
            deployed.reserve.setAaveUtilizationFeed(cfg.chainlinkFeed);
        }

        // 4. CleanvestSettlement (HEX borsa)
        gasBefore = gasleft();
        deployed.settlement = new CleanvestSettlement();
        totalDeployGas += _deployGas("CleanvestSettlement", gasBefore);
        if (cfg.chainlinkFeed != address(0)) {
            deployed.settlement.setChainlinkFeed(cfg.chainlinkFeed);
        }

        // 5. ListingGate (CleanAudit zorunlu)
        gasBefore = gasleft();
        deployed.gate = new ListingGate();
        totalDeployGas += _deployGas("ListingGate", gasBefore);
        if (cfg.cleanAuditOracle != address(0)) {
            deployed.gate.setCleanAuditOracle(cfg.cleanAuditOracle);
        }

        // 6. UniswapProxy (artik hacim)
        gasBefore = gasleft();
        deployed.proxy = new UniswapProxy(cfg.uniswapRouter);
        totalDeployGas += _deployGas("UniswapProxy", gasBefore);

        // 7. ReferralLedger (referans sistemi, docs/44)
        gasBefore = gasleft();
        deployed.referral = new ReferralLedger();
        totalDeployGas += _deployGas("ReferralLedger", gasBefore);

        vm.stopBroadcast();

        console.log("=== Deployment tamamlandi (7 sozlesme) ===");
        console.log("Toplam deploy gazi (yaklasik):", totalDeployGas);

        // Sozlesme adreslerini kaydet (sonraki adimlar icin)
        _logAddresses(chainId);
    }

    /// @dev Bir kontratin deploy gazini hesaplar ve loglar.
    function _deployGas(string memory name, uint256 gasBefore) internal returns (uint256) {
        uint256 used = gasBefore - gasleft();
        console.log("  gas:", name, used);
        return used;
    }

    /// @dev Adresleri hem loglar hem de JSON'a yazar (fs_permissions gerekir).
    function _logAddresses(uint256 chainId) internal {
        console.log("--- ADRESLER ---");
        console.log("cUSD:      ", address(deployed.cUSD));
        console.log("scUSD:     ", address(deployed.vault));
        console.log("reserve:   ", address(deployed.reserve));
        console.log("settlement:", address(deployed.settlement));
        console.log("gate:      ", address(deployed.gate));
        console.log("proxy:     ", address(deployed.proxy));
        console.log("referral:  ", address(deployed.referral));

        // JSON'a yaz (foundry.toml'de fs_permissions yazma izni gerekir).
        // Basarisiz olursa sessizce gec - log zaten yukarida verildi.
        try vm.writeFile(
            "deploy-out/addresses.json",
            string.concat(
                "{\n",
                string.concat(
                    '  "comment": "DEPLOY OUTPUT - chainId ', vm.toString(chainId), '",\n'
                ),
                string.concat('  "chainId": ', vm.toString(chainId), ",\n"),
                string.concat('  "CleanUSD": "', vm.toString(address(deployed.cUSD)), '",\n'),
                string.concat('  "CleanFXVault": "', vm.toString(address(deployed.vault)), '",\n'),
                string.concat(
                    '  "ReserveManager": "', vm.toString(address(deployed.reserve)), '",\n'
                ),
                string.concat(
                    '  "CleanvestSettlement": "', vm.toString(address(deployed.settlement)), '",\n'
                ),
                string.concat('  "ListingGate": "', vm.toString(address(deployed.gate)), '",\n'),
                string.concat('  "UniswapProxy": "', vm.toString(address(deployed.proxy)), '",\n'),
                string.concat(
                    '  "ReferralLedger": "', vm.toString(address(deployed.referral)), '"\n'
                ),
                "}"
            )
        ) {
            console.log("Adresler deploy-out/addresses.json'a yazildi");
        } catch {
            console.log("UYARI: deploy-out/addresses.json'a yazilamadi (fs izni?)");
        }
    }
}
