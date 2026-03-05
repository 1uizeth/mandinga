// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IYieldSourceAdapter} from "../../src/interfaces/IYieldSourceAdapter.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// @notice Controllable mock for IYieldSourceAdapter — used in YieldRouter unit tests.
contract MockSparkAdapter is IYieldSourceAdapter {
    MockUSDC public usdc;
    address public yieldRouter;

    uint256 public balance;
    uint256 public apyBps;
    bool public harvestReverts;
    bool public withdrawReverts;
    uint256 public lastHarvestYield;

    constructor(address _usdc, address _yieldRouter) {
        usdc = MockUSDC(_usdc);
        yieldRouter = _yieldRouter;
    }

    function deposit(uint256 amount) external override {
        usdc.transferFrom(msg.sender, address(this), amount);
        balance += amount;
    }

    function withdraw(uint256 amount) external override {
        if (withdrawReverts) revert("MockSparkAdapter: withdraw reverts");
        require(balance >= amount, "MockSparkAdapter: insufficient balance");
        balance -= amount;
        usdc.transfer(msg.sender, amount);
    }

    function withdrawMax(uint256 requested) external override returns (uint256 withdrawn) {
        withdrawn = balance < requested ? balance : requested;
        if (withdrawn > 0) {
            balance -= withdrawn;
            usdc.transfer(msg.sender, withdrawn);
        }
        if (withdrawn < requested) emit PartialWithdrawal(requested, withdrawn);
    }

    function getBalance() external view override returns (uint256) {
        return balance;
    }

    function getAPY() external view override returns (uint256) {
        return apyBps;
    }

    function getAsset() external view override returns (address) {
        return address(usdc);
    }

    function harvest() external override returns (uint256 yieldAmount) {
        if (harvestReverts) revert("MockSparkAdapter: harvest reverts");
        yieldAmount = lastHarvestYield;
        if (yieldAmount > 0) {
            usdc.transfer(msg.sender, yieldAmount);
            lastHarvestYield = 0;
        }
    }

    // ── Test helpers ──

    function setAPY(uint256 _apyBps) external {
        apyBps = _apyBps;
    }

    function setHarvestYield(uint256 yield_) external {
        usdc.mint(address(this), yield_);
        balance += yield_;
        lastHarvestYield = yield_;
    }

    function setWithdrawReverts(bool flag) external {
        withdrawReverts = flag;
    }
}
