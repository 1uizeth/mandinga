// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReceiverTemplate} from "../interfaces/cre/ReceiverTemplate.sol";
import {ISavingsCircle} from "../interfaces/ISavingsCircle.sol";

/// @title CircleFormationConsumer
/// @notice CRE consumer that receives reports and calls SavingsCircle.createCircle.
/// @dev Deploy with MockForwarder for simulation, KeystoneForwarder for production.
///      See https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
contract CircleFormationConsumer is ReceiverTemplate {
    event CircleCreated(uint256 indexed circleId, address indexed savingsCircle, uint256 poolSize, uint16 memberCount);

    constructor(address _forwarderAddress) ReceiverTemplate(_forwarderAddress) {}

    /// @inheritdoc ReceiverTemplate
    function _processReport(bytes calldata report) internal override {
        (address savingsCircle, uint256 poolSize, uint16 memberCount, uint256 roundDuration, uint256 minDepositPerRound) =
            abi.decode(report, (address, uint256, uint16, uint256, uint256));

        uint256 circleId = ISavingsCircle(savingsCircle).createCircle(
            poolSize, memberCount, roundDuration, minDepositPerRound
        );

        emit CircleCreated(circleId, savingsCircle, poolSize, memberCount);
    }
}
