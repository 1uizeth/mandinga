// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReceiverTemplate} from "../interfaces/cre/ReceiverTemplate.sol";
import {ISavingsCircle} from "../interfaces/ISavingsCircle.sol";

/// @title ExecuteRoundConsumer
/// @notice CRE consumer that receives reports and calls SavingsCircle.executeRound.
/// @dev Deploy with MockForwarder for simulation, KeystoneForwarder for production.
///      See https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
contract ExecuteRoundConsumer is ReceiverTemplate {
    event RoundExecuted(address indexed savingsCircle, uint256 indexed circleId);

    constructor(address _forwarderAddress) ReceiverTemplate(_forwarderAddress) {}

    /// @inheritdoc ReceiverTemplate
    function _processReport(bytes calldata report) internal override {
        (address savingsCircle, uint256 circleId) = abi.decode(report, (address, uint256));

        ISavingsCircle(savingsCircle).executeRound(circleId);

        emit RoundExecuted(savingsCircle, circleId);
    }
}
