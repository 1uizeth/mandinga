// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {YieldHarvestConsumer} from "../src/core/YieldHarvestConsumer.sol";

/// @notice Deploys YieldHarvestConsumer for CRE yield-harvest workflow.
/// @dev Use MockForwarder for simulation, KeystoneForwarder for production.
///      See https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
///
/// Usage:
///   FORWARDER_ADDRESS=0x... forge script script/DeployYieldHarvestConsumer.s.sol --broadcast --rpc-url <RPC>
contract DeployYieldHarvestConsumer is Script {
    function run() external {
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");

        vm.startBroadcast();
        YieldHarvestConsumer consumer = new YieldHarvestConsumer(forwarder);
        vm.stopBroadcast();

        console.log("YieldHarvestConsumer deployed at:", address(consumer));
    }
}
