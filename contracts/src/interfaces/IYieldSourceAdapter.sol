// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IYieldSourceAdapter
/// @notice Interface for yield source adapters consumed by the YieldRouter.
/// @dev v1 implementation: SparkUsdcVaultAdapter (Sky Savings Rate on Base).
interface IYieldSourceAdapter {
    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a partial withdrawal is executed due to PSM liquidity cap.
    event PartialWithdrawal(uint256 requested, uint256 withdrawn);

    // ──────────────────────────────────────────────
    // Functions
    // ──────────────────────────────────────────────

    /// @notice Deposit USDC into the underlying yield source.
    /// @param amount USDC amount (6 decimals)
    function deposit(uint256 amount) external;

    /// @notice Withdraw USDC from the underlying yield source.
    /// @param amount USDC amount (6 decimals)
    /// @dev Reverts if PSM liquidity is insufficient. Use `withdrawMax` as a fallback.
    function withdraw(uint256 amount) external;

    /// @notice Partial withdrawal fallback — withdraws up to available PSM liquidity.
    /// @param requested USDC amount requested (6 decimals)
    /// @return withdrawn Actual USDC amount transferred to the caller
    function withdrawMax(uint256 requested) external returns (uint256 withdrawn);

    /// @notice Current USDC balance including accrued yield (6 decimals).
    /// @return balance USDC value of all held shares
    function getBalance() external view returns (uint256 balance);

    /// @notice Current APY in basis points (10000 = 100%).
    /// @return apy Annualised yield rate derived from rateProvider.getConversionRate() delta
    function getAPY() external view returns (uint256 apy);

    /// @notice The underlying asset address (USDC).
    /// @return asset Address of the ERC-20 stablecoin accepted by this adapter
    function getAsset() external view returns (address asset);

    /// @notice Collect and return yield earned since the last harvest.
    /// @return yieldAmount USDC yield (6 decimals) transferred to the YieldRouter
    function harvest() external returns (uint256 yieldAmount);
}
