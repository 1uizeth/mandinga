// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title IYieldRouter
/// @notice ERC4626-compliant yield router interface.
/// @dev Extends IERC4626 — `deposit()` and `withdraw()` are inherited and must not be redefined.
///      SavingsAccount uses `allocate()` to commit capital and `withdraw()` to reclaim it.
///      v1 sole adapter: SparkUsdcVaultAdapter (Sky Savings Rate on Base).
interface IYieldRouter is IERC4626 {
    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when capital is allocated from SavingsAccount.
    event CapitalAllocated(uint256 amount, uint256 timestamp);

    /// @notice Emitted when capital is returned to SavingsAccount.
    event CapitalWithdrawn(uint256 amount, uint256 timestamp);

    /// @notice Emitted after a successful yield harvest.
    event YieldHarvested(
        uint256 grossYield,
        uint256 protocolFee,
        uint256 bufferContribution,
        uint256 netYield,
        uint256 timestamp
    );

    /// @notice Emitted when the circuit breaker is tripped (new deposits blocked).
    event CircuitBreakerTripped(string reason, uint256 timestamp);

    /// @notice Emitted when the circuit breaker is reset.
    event CircuitBreakerReset(uint256 timestamp);

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    /// @notice Raised on deposit/harvest calls while the circuit breaker is active.
    error CircuitBreakerActive();

    // ──────────────────────────────────────────────
    // Protocol-specific functions
    // ──────────────────────────────────────────────

    /// @notice Allocate USDC from the calling SavingsAccount into the active yield source.
    /// @dev Pulls `amount` from `msg.sender` via transferFrom; mints corresponding shares.
    /// @param amount USDC amount to allocate (6 decimals)
    function allocate(uint256 amount) external;

    /// @notice Collect yield from the active adapter; yield accrues as share price appreciation.
    function harvest() external;

    /// @notice Current blended APY across all active adapters.
    /// @return apy Basis points (10000 = 100%)
    function getBlendedAPY() external view returns (uint256 apy);

    /// @notice Whether the circuit breaker is currently active.
    /// @return active True when new deposits are blocked
    function getCircuitBreakerStatus() external view returns (bool active);

    /// @notice Total USDC capital under management (mirrors `totalAssets()`).
    /// @return total USDC (6 decimals)
    function getTotalAllocated() external view returns (uint256 total);
}
