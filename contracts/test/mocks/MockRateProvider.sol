// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Mock for Sky Protocol's rate provider.
///         Returns a configurable conversion rate (ray = 1e27 precision).
contract MockRateProvider {
    uint256 public conversionRate;

    /// @param initialRate Starting rate in ray (e.g. 1e27 = 1.0).
    constructor(uint256 initialRate) {
        conversionRate = initialRate;
    }

    /// @notice Returns the current conversion rate.
    function getConversionRate() external view returns (uint256) {
        return conversionRate;
    }

    /// @dev Test helper to advance the rate.
    function setConversionRate(uint256 newRate) external {
        conversionRate = newRate;
    }
}
