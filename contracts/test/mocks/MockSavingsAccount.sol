// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";

/// @dev Minimal ISavingsAccount mock for SavingsCircle unit tests.
///      Tracks obligation and creditPrincipal calls; does NOT enforce balance invariants.
contract MockSavingsAccount is ISavingsAccount {
    mapping(bytes32 => Position) public positions;
    mapping(address => bytes32) private _shieldedIds;

    // ── Test setup helpers ──

    function setPosition(bytes32 shieldedId, uint256 balance, uint256 obligation) external {
        positions[shieldedId].balance = balance;
        positions[shieldedId].circleObligation = obligation;
    }

    function registerShieldedId(address user, bytes32 shieldedId) external {
        _shieldedIds[user] = shieldedId;
    }

    // ── ISavingsAccount ──

    function computeShieldedId(address user) external view override returns (bytes32) {
        bytes32 stored = _shieldedIds[user];
        if (stored != bytes32(0)) return stored;
        return keccak256(abi.encodePacked(user, uint256(0)));
    }

    function getWithdrawableBalance(bytes32 shieldedId) external view override returns (uint256) {
        Position storage pos = positions[shieldedId];
        if (pos.balance < pos.circleObligation) return 0;
        return pos.balance - pos.circleObligation;
    }

    function getCircleObligation(bytes32 shieldedId) external view override returns (uint256) {
        return positions[shieldedId].circleObligation;
    }

    function getPosition(bytes32 shieldedId) external view override returns (Position memory) {
        return positions[shieldedId];
    }

    function setCircleObligation(bytes32 shieldedId, uint256 amount) external override {
        positions[shieldedId].circleObligation = amount;
        emit ObligationSet(shieldedId, amount);
    }

    function creditPrincipal(bytes32 shieldedId, uint256 amount) external override {
        positions[shieldedId].balance += amount;
        emit YieldCredited(shieldedId, amount);
    }

    // ── Safety Net Pool integration (Task 003-02, 03, 04) ──

    mapping(bytes32 => uint256) public safetyNetDebtShares;

    function addSafetyNetDebt(bytes32 shieldedId, uint256 shares) external override {
        safetyNetDebtShares[shieldedId] += shares;
        emit SafetyNetDebtAdded(shieldedId, shares);
    }

    function getSafetyNetDebtShares(bytes32 shieldedId) external view override returns (uint256) {
        return safetyNetDebtShares[shieldedId];
    }

    function clearSafetyNetDebt(bytes32 shieldedId) external override {
        uint256 settled = safetyNetDebtShares[shieldedId];
        safetyNetDebtShares[shieldedId] = 0;
        emit SafetyNetDebtCleared(shieldedId, settled);
    }

    function chargeFromYield(bytes32 shieldedId, uint256 amount) external override {
        Position storage pos = positions[shieldedId];
        if (pos.balance < amount) revert PositionInsolvent(shieldedId);
        pos.balance -= amount;
        if (pos.yieldEarnedTotal >= amount) {
            pos.yieldEarnedTotal -= amount;
        } else {
            pos.yieldEarnedTotal = 0;
        }
        emit YieldCharged(shieldedId, amount, 0, 0);
    }

    // ── Stubs for unused interface functions ──

    function deposit(uint256) external override {}
    function withdraw(uint256) external override {}
    function emergencyWithdraw() external override {}
    function activateEmergency() external override {}

    function creditYield(bytes32, uint256) external {}
}
