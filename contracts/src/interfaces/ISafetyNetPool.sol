// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICircleBuffer} from "./ICircleBuffer.sol";

/// @title ISafetyNetPool
/// @notice Combined interface for the Safety Net Pool used by SavingsCircle.
///         Extends ICircleBuffer so coverSlot / releaseSlot are also available.
interface ISafetyNetPool is ICircleBuffer {
    // ──────────────────────────────────────────────
    // Gap coverage (Task 003-02)
    // ──────────────────────────────────────────────

    /// @notice Cover the gap between contributionPerMember and minDepositPerRound for a slot.
    /// @dev Callable only by the authorised SavingsCircle. memberId passed directly to avoid
    ///      a circular dependency (pool never calls back into SavingsCircle).
    /// @param circleId  The circle executing the round
    /// @param slot      The slot of the min-installment member
    /// @param memberId  shieldedId of the member (from _members[circleId][slot])
    /// @param gap       USDC gap to cover this round (contributionPerMember - minDepositPerRound)
    function coverGap(uint256 circleId, uint16 slot, bytes32 memberId, uint256 gap) external;

    // ──────────────────────────────────────────────
    // Debt settlement (Task 003-03)
    // ──────────────────────────────────────────────

    /// @notice Undeployed USDC available for new coverages.
    function getAvailableCapital() external view returns (uint256);

    /// @notice Settle and release all gap debt for a slot at payout time.
    /// @dev Callable only by the authorised SavingsCircle (from claimPayout).
    ///      Decrements totalDeployed, deletes gapCoverages entry.
    ///      Reverts GapNotFound if no gap coverage exists for this slot.
    /// @param circleId  The circle whose member is being paid out
    /// @param slot      The slot of the selected member
    function settleGapDebt(uint256 circleId, uint16 slot) external;

    /// @notice Current USDC value of the gap debt shares for a slot.
    /// @dev Returns yieldRouter.convertToAssets(totalDeployedShares) — current market value.
    function convertGapToUsdc(uint256 circleId, uint16 slot) external view returns (uint256);

    // ──────────────────────────────────────────────
    // Interest accrual (Task 003-04)
    // ──────────────────────────────────────────────

    /// @notice Accrue and charge interest on a covered slot's debt.
    /// @dev Permissionless — callable by anyone. Guards: MIN_ACCRUAL_INTERVAL, rate == 0,
    ///      slot not active. Reverts PositionInsolvent if member cannot pay.
    function accrueInterest(uint256 circleId, uint16 slot) external;

    /// @notice Outstanding interest since last accrual (USDC, read-only).
    function getAccruedInterest(uint256 circleId, uint16 slot) external view returns (uint256);

    /// @notice Estimated net payout breakdown for a min-installment member.
    /// @return grossUsdc   Full pool size
    /// @return debtUsdc    Current value of gap debt shares
    /// @return interestUsdc Outstanding accrued interest
    /// @return netUsdc     grossUsdc - debtUsdc - interestUsdc (floored at 0)
    function getEstimatedNetPayout(uint256 circleId, uint16 slot)
        external
        view
        returns (uint256 grossUsdc, uint256 debtUsdc, uint256 interestUsdc, uint256 netUsdc);
}
