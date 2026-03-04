// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICircleBuffer} from "../../src/interfaces/ICircleBuffer.sol";

/// @dev No-op CircleBuffer mock for unit and integration tests.
contract MockCircleBuffer is ICircleBuffer {
    struct CoverCall { uint256 circleId; uint16 slot; uint256 amount; }
    struct ReleaseCall { uint256 circleId; uint16 slot; }

    CoverCall[] public coverCalls;
    ReleaseCall[] public releaseCalls;

    function coverSlot(uint256 circleId, uint16 slot, uint256 amount) external override {
        coverCalls.push(CoverCall(circleId, slot, amount));
    }

    function releaseSlot(uint256 circleId, uint16 slot) external override {
        releaseCalls.push(ReleaseCall(circleId, slot));
    }

    function coverCallCount() external view returns (uint256) { return coverCalls.length; }
    function releaseCallCount() external view returns (uint256) { return releaseCalls.length; }
}
