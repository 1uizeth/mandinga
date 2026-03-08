// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISavingsCircle
/// @notice Minimal interface for circle creation (CRE consumer use).
interface ISavingsCircle {
    function createCircle(
        uint256 poolSize,
        uint16 memberCount,
        uint256 roundDuration,
        uint256 minDepositPerRound
    ) external returns (uint256 circleId);
}
