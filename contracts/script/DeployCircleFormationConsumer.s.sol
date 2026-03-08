// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {CircleFormationConsumer} from "../src/core/CircleFormationConsumer.sol";

/// @notice Deploys CircleFormationConsumer for CRE circle-formation workflow.
/// @dev Use MockForwarder for simulation, KeystoneForwarder for production.
///      See https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
///
/// Usage:
///   FORWARDER_ADDRESS=0x... forge script script/DeployCircleFormationConsumer.s.sol --broadcast --rpc-url <RPC>
contract DeployCircleFormationConsumer is Script {
    function run() external {
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");

        vm.startBroadcast();
        CircleFormationConsumer consumer = new CircleFormationConsumer(forwarder);
        vm.stopBroadcast();

        console.log("CircleFormationConsumer deployed at:", address(consumer));
    }
}
