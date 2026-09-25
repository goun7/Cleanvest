// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../contracts/CleanUSD.sol";
import "../contracts/CleanFXVault.sol";
import "../contracts/ReserveManager.sol";
import "../contracts/CleanvestSettlement.sol";
import "../contracts/ListingGate.sol";
import "../contracts/UniswapProxy.sol";

/// @title Deploy - Cleanvest Tam Stack Deployment
/// @author Cleanvest
/// @notice 6 sozlesmeyi sirayla deploy eder ve birbirine baglar.
/// @dev Kullanim:
///      forge script script/Deploy.s.sol:Deploy --rpc-url $BASE_RPC \
///          --private-key $PK --broadcast --verify
///
///      ORNEK (yerel test, dry-run):
///      forge script script/Deploy.s.sol:Deploy
library DeploymentConfig {
    /// @notice Production adresleri (Base mainnet). Deployment sirasinda ENV'den alinir.
    /// @dev Bunlar yalnizca ORNEKLEMEdir - gercek deploy'da .env dogrulanmali.
    struct Config {
        address usdc;              // Base USDC
        address aavePool;          // Aave V3 Pool (Base)
        address aavePrimePool;     // Aave Prime Pool
        address chainlinkFeed;     // Chainlink USDC/USD feed
        address uniswapRouter;     // Uniswap V3 SwapRouter
        address aegisForgeOracle;  // AegisForge motor adresi (off-chain imzaci)
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
    }

    Deployed public deployed;
    DeploymentConfig.Config public cfg;

    function run() external {
        // Tum adresler ENV'den okunur - UYDURMA ADRES KULLANILMAZ
        cfg = DeploymentConfig.Config({
            usdc: vm.envOr("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),  // Base USDC
            aavePool: vm.envOr("AAVE_POOL", address(0)),
            aavePrimePool: vm.envOr("AAVE_PRIME_POOL", address(0)),
            chainlinkFeed: vm.envOr("CHAINLINK_FEED", address(0)),
            uniswapRouter: vm.envOr("UNISWAP_ROUTER", address(0)),
            aegisForgeOracle: vm.envOr("AEGISFORGE_ORACLE", address(0))
        });

        string memory network = vm.envOr("NETWORK", string("local-test"));
        console.log("Network:", network);

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        if (pk != 0) {
            vm.startBroadcast(pk);
        } else {
            // Dry-run: anvil'in varsayilan anahtari
            vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf8ff42ff);
        }

        console.log("=== Cleanvest Deployment basliyor ===");
        console.log("Network:", network);

        // 1. CleanUSD (sabit $1.00, REBASE YOK)
        deployed.cUSD = new CleanUSD();
        console.log("CleanUSD:", address(deployed.cUSD));

        // 2. CleanFXVault (asset = cUSD)
        deployed.vault = new CleanFXVault(address(deployed.cUSD));
        console.log("CleanFXVault:", address(deployed.vault));

        // 3. ReserveManager (Aave katmani)
        deployed.reserve = new ReserveManager(cfg.usdc);
        if (cfg.aavePool != address(0)) deployed.reserve.setAavePool(cfg.aavePool);
        if (cfg.aavePrimePool != address(0)) deployed.reserve.setAavePrimePool(cfg.aavePrimePool);
        if (cfg.chainlinkFeed != address(0)) {
            deployed.reserve.setAaveUtilizationFeed(cfg.chainlinkFeed);
        }
        console.log("ReserveManager:", address(deployed.reserve));

        // 4. CleanvestSettlement (HEX borsa)
        deployed.settlement = new CleanvestSettlement();
        if (cfg.chainlinkFeed != address(0)) {
            deployed.settlement.setChainlinkFeed(cfg.chainlinkFeed);
        }
        console.log("CleanvestSettlement:", address(deployed.settlement));

        // 5. ListingGate (AegisForge zorunlu)
        deployed.gate = new ListingGate();
        if (cfg.aegisForgeOracle != address(0)) {
            deployed.gate.setAegisForgeOracle(cfg.aegisForgeOracle);
        }
        console.log("ListingGate:", address(deployed.gate));

        // 6. UniswapProxy (artik hacim)
        deployed.proxy = new UniswapProxy(cfg.uniswapRouter);
        console.log("UniswapProxy:", address(deployed.proxy));

        vm.stopBroadcast();

        console.log("=== Deployment tamamlandi (6 sozlesme) ===");

        // Sozlesme adreslerini kaydet (sonraki adimlar icin)
        _logAddresses();
    }

    function _logAddresses() internal view {
        console.log("--- ADRESLER ---");
        console.log("cUSD:      ", address(deployed.cUSD));
        console.log("scUSD:     ", address(deployed.vault));
        console.log("reserve:   ", address(deployed.reserve));
        console.log("settlement:", address(deployed.settlement));
        console.log("gate:      ", address(deployed.gate));
        console.log("proxy:     ", address(deployed.proxy));
    }
}
