// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";
import {MockUSDC} from "./MockUSDC.sol";

contract MockYieldRouter is IYieldRouter {
    MockUSDC public usdc;
    uint256 public totalAllocated;

    constructor(address _usdc) {
        usdc = MockUSDC(_usdc);
    }

    // ── IYieldRouter protocol functions ──

    function allocate(uint256 amount) external override {
        usdc.transferFrom(msg.sender, address(this), amount);
        totalAllocated += amount;
    }

    function harvest() external override {}

    function getBlendedAPY() external pure override returns (uint256) {
        return 500; // 5% in bps
    }

    function getCircuitBreakerStatus() external pure override returns (bool) {
        return false;
    }

    function getTotalAllocated() external view override returns (uint256) {
        return totalAllocated;
    }

    // ── IERC4626 (inherited) ── minimal stubs ──

    function asset() external view override returns (address) {
        return address(usdc);
    }

    function totalAssets() external view override returns (uint256) {
        return totalAllocated;
    }

    function convertToShares(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address) external view override returns (uint256) {
        return totalAllocated;
    }

    function maxRedeem(address) external view override returns (uint256) {
        return totalAllocated;
    }

    function previewDeposit(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function previewMint(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function previewWithdraw(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function previewRedeem(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        usdc.transferFrom(msg.sender, address(this), assets);
        totalAllocated += assets;
        emit Deposit(msg.sender, receiver, assets, assets);
        return assets;
    }

    function mint(uint256 shares, address receiver) external override returns (uint256) {
        usdc.transferFrom(msg.sender, address(this), shares);
        totalAllocated += shares;
        emit Deposit(msg.sender, receiver, shares, shares);
        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        totalAllocated -= assets;
        usdc.transfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, assets);
        return assets;
    }

    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        totalAllocated -= shares;
        usdc.transfer(receiver, shares);
        emit Withdraw(msg.sender, receiver, owner, shares, shares);
        return shares;
    }

    // ── IERC20 (IERC4626 extends IERC20) ── minimal stubs ──

    function name() external pure override returns (string memory) {
        return "Mock YieldRouter";
    }

    function symbol() external pure override returns (string memory) {
        return "MYR";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    function totalSupply() external pure override returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure override returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }
}
