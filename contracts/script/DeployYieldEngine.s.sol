// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SavingsAccount} from "../src/core/SavingsAccount.sol";
import {SavingsCircle} from "../src/core/SavingsCircle.sol";
import {SafetyNetPool} from "../src/core/SafetyNetPool.sol";
import {SparkUsdcVaultAdapter} from "../src/yield/SparkUsdcVaultAdapter.sol";
import {YieldRouter} from "../src/yield/YieldRouter.sol";
import {ISavingsAccount} from "../src/interfaces/ISavingsAccount.sol";
import {ISafetyNetPool} from "../src/interfaces/ISafetyNetPool.sol";
import {IYieldRouter} from "../src/interfaces/IYieldRouter.sol";

struct DeployConfig {
    address usdc;
    address vault;
    address rateProvider;
    address vrfCoordinator;
    address deployer;
    address emergencyModule;
    address circleBuffer;
    address treasury;
    address governance;
    uint256 initialRateBps;
    bytes32 keyHash;
    uint64 subscriptionId;
}

/// @notice Deploys SavingsAccount, SparkUsdcVaultAdapter, YieldRouter, SafetyNetPool,
///         and SavingsCircle to Base Sepolia.
/// @dev Loads addresses from config/base-sepolia.json. Uses vm.computeCreateAddress to break
///      circular dependencies (SavingsAccount <-> YieldRouter, SafetyNetPool <-> SavingsCircle).
contract DeployYieldEngine is Script {
    using stdJson for string;

    function _loadConfig() internal view returns (DeployConfig memory c) {
        string memory configJson = vm.readFile("config/base-sepolia.json");
        c.usdc = configJson.readAddress(".sky.mockUsdc");
        c.vault = configJson.readAddress(".sky.usdcVaultL2");
        c.rateProvider = configJson.readAddress(".sky.mockRateProvider");
        c.vrfCoordinator = configJson.readAddress(".chainlink.vrfCoordinator");

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        c.deployer = pk != 0 ? vm.addr(pk) : msg.sender;
        c.emergencyModule = vm.envOr("EMERGENCY_MODULE", c.deployer);
        c.circleBuffer = vm.envOr("CIRCLE_BUFFER", c.deployer);
        c.treasury = vm.envOr("TREASURY", c.deployer);
        c.governance = vm.envOr("GOVERNANCE", c.deployer);
        c.initialRateBps = vm.envOr("SAFETY_NET_INITIAL_RATE_BPS", uint256(0));

        uint256 vrfKeyHashEnv = vm.envOr("VRF_KEYHASH", uint256(0));
        c.keyHash = vrfKeyHashEnv != 0 ? bytes32(vrfKeyHashEnv) : configJson.readBytes32(".chainlink.keyHash");
        uint256 subId = vm.envOr("CHAINLINK_SUBSCRIPTION_ID", uint256(0));
        c.subscriptionId = subId != 0 ? uint64(subId) : uint64(configJson.readUint(".chainlink.subscriptionId"));
    }

    function run() external {
        DeployConfig memory c = _loadConfig();
        uint256 nonce = vm.getNonce(c.deployer);
        address yrAddr = vm.computeCreateAddress(c.deployer, nonce + 2);
        address snpAddr = vm.computeCreateAddress(c.deployer, nonce + 3);
        address scAddr = vm.computeCreateAddress(c.deployer, nonce + 4);

        vm.startBroadcast();

        SavingsAccount savingsAccount = new SavingsAccount(
            IYieldRouter(yrAddr),
            c.emergencyModule,
            scAddr,
            c.usdc,
            snpAddr
        );

        SparkUsdcVaultAdapter adapter = new SparkUsdcVaultAdapter(
            c.vault,
            c.usdc,
            c.rateProvider,
            yrAddr
        );

        YieldRouter yieldRouter = new YieldRouter(
            c.usdc,
            address(adapter),
            address(savingsAccount),
            c.circleBuffer,
            c.treasury
        );

        SafetyNetPool safetyNetPool = new SafetyNetPool(
            ISavingsAccount(address(savingsAccount)),
            IYieldRouter(address(yieldRouter)),
            IERC20(c.usdc),
            scAddr,
            c.governance,
            c.initialRateBps
        );

        SavingsCircle savingsCircle = new SavingsCircle(
            ISavingsAccount(address(savingsAccount)),
            ISafetyNetPool(address(safetyNetPool)),
            c.vrfCoordinator,
            c.keyHash,
            c.subscriptionId
        );

        vm.stopBroadcast();

        console.log("Deployed to Base Sepolia:");
        console.log("SavingsAccount:       ", address(savingsAccount));
        console.log("SparkUsdcVaultAdapter:", address(adapter));
        console.log("YieldRouter:          ", address(yieldRouter));
        console.log("SafetyNetPool:        ", address(safetyNetPool));
        console.log("SavingsCircle:        ", address(savingsCircle));
    }
}
