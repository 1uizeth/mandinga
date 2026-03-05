// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// @notice Minimal mock for UsdcVaultL2 (Sky ERC4626 on Base).
///         Stores USDC balances and simulates yield via `setYieldMultiplier`.
contract MockUsdcVaultL2 {
    MockUSDC public usdc;

    /// @dev Track sUSDC shares (18 dec) per depositor.
    mapping(address => uint256) private _shares;
    uint256 private _totalShares;
    uint256 private _totalAssets;

    /// @dev Simulates yield: balanceOf(depositor) * multiplier / 1e18.
    uint256 public yieldMultiplier = 1e18; // 1:1 initially

    /// @dev PSM pocket cap — limits maxWithdraw. type(uint256).max = uncapped.
    uint256 public psmCap = type(uint256).max;

    constructor(address _usdc) {
        usdc = MockUSDC(_usdc);
    }

    // ── ERC4626-compatible interface ──

    function asset() external view returns (address) {
        return address(usdc);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        usdc.transferFrom(msg.sender, address(this), assets);
        shares = (assets * 1e18) / _sharePrice();
        _shares[receiver] += shares;
        _totalShares += shares;
        _totalAssets += assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        shares = (assets * 1e18) / _sharePrice();
        require(_shares[owner] >= shares, "MockVault: insufficient shares");
        _shares[owner] -= shares;
        _totalShares -= shares;
        _totalAssets -= assets;
        usdc.transfer(receiver, assets);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _shares[account];
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        if (_totalShares == 0) return shares;
        return (shares * _sharePrice()) / 1e18;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return (assets * 1e18) / _sharePrice();
    }

    function maxWithdraw(address) external view returns (uint256) {
        return psmCap;
    }

    /// @notice Emergency exit — transfers shares (mock: transfers USDC equivalent instead).
    function exit(uint256 shares, address receiver, address) external returns (uint256) {
        uint256 assets = (shares * _sharePrice()) / 1e18;
        _shares[msg.sender] -= shares;
        _totalShares -= shares;
        _totalAssets -= assets;
        usdc.transfer(receiver, assets);
        return assets;
    }

    // ── Test helpers ──

    /// @dev Simulates yield: multiply share price. Call to advance time-based yield.
    function setYieldMultiplier(uint256 multiplier) external {
        yieldMultiplier = multiplier;
    }

    /// @dev Directly mint USDC into vault to simulate yield accrual without share changes.
    function accrueYield(uint256 extraUsdc) external {
        usdc.mint(address(this), extraUsdc);
        _totalAssets += extraUsdc;
    }

    /// @dev Limit maxWithdraw to simulate PSM pocket cap.
    function setPsmCap(uint256 cap) external {
        psmCap = cap;
    }

    function _sharePrice() internal view returns (uint256) {
        if (_totalShares == 0) return 1e18;
        return (_totalAssets * yieldMultiplier * 1e18) / (_totalShares * 1e18);
    }
}
