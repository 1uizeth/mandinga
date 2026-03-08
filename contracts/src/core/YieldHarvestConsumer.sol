// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReceiverTemplate} from "../interfaces/cre/ReceiverTemplate.sol";
import {IYieldRouter} from "../interfaces/IYieldRouter.sol";

/// @title YieldHarvestConsumer
/// @notice CRE consumer that receives reports and calls YieldRouter.harvest().
/// @dev Deploy with MockForwarder for simulation, KeystoneForwarder for production.
///      See https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
contract YieldHarvestConsumer is ReceiverTemplate {
    event HarvestExecuted(address indexed yieldRouter);

    constructor(address _forwarderAddress) ReceiverTemplate(_forwarderAddress) {}

    /// @inheritdoc ReceiverTemplate
    function _processReport(bytes calldata report) internal override {
        address yieldRouter = abi.decode(report, (address));
        IYieldRouter(yieldRouter).harvest();
        emit HarvestExecuted(yieldRouter);
    }
}
