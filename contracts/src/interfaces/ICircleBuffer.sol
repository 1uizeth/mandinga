// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICircleBuffer
/// @notice Interface for the Safety Net Pool buffer that covers paused members' contributions
///         during a grace period. Full implementation is in Spec 003 (Milestone 4).
interface ICircleBuffer {
    /// @notice Instruct the buffer to cover a paused member's slot for the grace period.
    /// @dev Called by SavingsCircle when a member's balance falls below their obligation.
    /// @param circleId The circle containing the paused slot
    /// @param slot     The slot index of the paused member
    /// @param amount   USDC contribution amount to cover per round (6 decimals)
    function coverSlot(uint256 circleId, uint16 slot, uint256 amount) external;

    /// @notice Release the buffer's coverage for a slot when the member resumes.
    /// @param circleId The circle containing the resumed slot
    /// @param slot     The slot index of the resumed member
    function releaseSlot(uint256 circleId, uint16 slot) external;
}
