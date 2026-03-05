// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISafetyNetPool} from "../../src/interfaces/ISafetyNetPool.sol";

/// @dev Mock ISafetyNetPool for SavingsCircle unit tests.
contract MockSafetyNetPool is ISafetyNetPool {
    // ── ICircleBuffer stubs ──

    struct CoverSlotCall { uint256 circleId; uint16 slot; uint256 amount; }
    struct ReleaseSlotCall { uint256 circleId; uint16 slot; }
    struct CoverGapCall { uint256 circleId; uint16 slot; bytes32 memberId; uint256 gap; }
    struct SettleDebtCall { uint256 circleId; uint16 slot; }

    CoverSlotCall[] public coverSlotCalls;
    ReleaseSlotCall[] public releaseSlotCalls;
    CoverGapCall[] public coverGapCalls;
    SettleDebtCall[] public settleDebtCalls;

    mapping(uint256 => mapping(uint16 => uint256)) public gapDebtUsdc;
    uint256 public availableCapitalOverride;
    bool public coverGapShouldRevert;

    uint256 public constant MIN_MIN_DEPOSIT = 1e6;

    function setAvailableCapital(uint256 amount) external { availableCapitalOverride = amount; }
    function setGapDebtUsdc(uint256 circleId, uint16 slot, uint256 usdc) external {
        gapDebtUsdc[circleId][slot] = usdc;
    }
    function setCoverGapShouldRevert(bool v) external { coverGapShouldRevert = v; }

    function coverSlot(uint256 circleId, uint16 slot, uint256 amount) external override {
        coverSlotCalls.push(CoverSlotCall(circleId, slot, amount));
    }

    function releaseSlot(uint256 circleId, uint16 slot) external override {
        releaseSlotCalls.push(ReleaseSlotCall(circleId, slot));
    }

    function coverGap(uint256 circleId, uint16 slot, bytes32 memberId, uint256 gap) external override {
        if (coverGapShouldRevert) revert("MockPool: insufficient capital");
        coverGapCalls.push(CoverGapCall(circleId, slot, memberId, gap));
    }

    function settleGapDebt(uint256 circleId, uint16 slot) external override {
        settleDebtCalls.push(SettleDebtCall(circleId, slot));
        gapDebtUsdc[circleId][slot] = 0;
    }

    function convertGapToUsdc(uint256 circleId, uint16 slot) external view override returns (uint256) {
        return gapDebtUsdc[circleId][slot];
    }

    function accrueInterest(uint256, uint16) external override {}

    function getAccruedInterest(uint256, uint16) external pure override returns (uint256) { return 0; }

    function getEstimatedNetPayout(uint256, uint16)
        external pure override
        returns (uint256 grossUsdc, uint256 debtUsdc, uint256 interestUsdc, uint256 netUsdc)
    {
        return (0, 0, 0, 0);
    }

    function getAvailableCapital() external view returns (uint256) { return availableCapitalOverride; }

    // ── Call count helpers ──
    function coverSlotCallCount() external view returns (uint256) { return coverSlotCalls.length; }
    function releaseSlotCallCount() external view returns (uint256) { return releaseSlotCalls.length; }
    function coverGapCallCount() external view returns (uint256) { return coverGapCalls.length; }
    function settleDebtCallCount() external view returns (uint256) { return settleDebtCalls.length; }
}
