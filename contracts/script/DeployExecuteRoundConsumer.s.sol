// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ExecuteRoundConsumer} from "../src/core/ExecuteRoundConsumer.sol";

/// @notice Deploys ExecuteRoundConsumer for CRE execute-round workflow.
/// @dev Use MockForwarder for simulation, KeystoneForwarder for production.
///      See https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
///
/// Usage:
///   FORWARDER_ADDRESS=0x... forge script script/DeployExecuteRoundConsumer.s.sol --broadcast --rpc-url <RPC>
contract DeployExecuteRoundConsumer is Script {
    function run() external {
        address forwarder = vm.envAddress("FORWARDER_ADDRESS");

        vm.startBroadcast();
        ExecuteRoundConsumer consumer = new ExecuteRoundConsumer(forwarder);
        vm.stopBroadcast();

        console.log("ExecuteRoundConsumer deployed at:", address(consumer));
    }
}
