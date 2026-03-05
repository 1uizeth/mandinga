// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SafetyNetPool} from "../../src/core/SafetyNetPool.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";
import {ICircleBuffer} from "../../src/interfaces/ICircleBuffer.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockYieldRouter} from "../mocks/MockYieldRouter.sol";
import {MockSavingsAccount} from "../mocks/MockSavingsAccount.sol";

contract SafetyNetPoolTest is Test {
    // ── Local event copies ──
    event Deposited(bytes32 indexed shieldedId, uint256 amount, uint256 lockDuration, uint256 newPoolShares);
    event Withdrawn(bytes32 indexed shieldedId, uint256 amount, uint256 burntPoolShares);
    event SlotCovered(uint256 indexed circleId, uint16 indexed slot, uint256 amount);
    event SlotReleased(uint256 indexed circleId, uint16 indexed slot, uint256 amount);
    event CoverageRateUpdated(uint256 oldBps, uint256 newBps);

    MockUSDC internal usdc;
    MockYieldRouter internal router;
    MockSavingsAccount internal sa;
    SafetyNetPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal circleAddr = makeAddr("circle");
    address internal gov = makeAddr("gov");

    uint256 internal constant DEPOSIT = 1_000e6;    // $1000 USDC
    uint256 internal constant RATE_BPS = 500;       // 5% annual

    function setUp() public {
        usdc = new MockUSDC();
        router = new MockYieldRouter(address(usdc));
        sa = new MockSavingsAccount();
        pool = new SafetyNetPool(
            ISavingsAccount(address(sa)),
            IYieldRouter(address(router)),
            usdc,
            circleAddr,
            gov,
            RATE_BPS
        );

        usdc.mint(alice, DEPOSIT * 3);
        usdc.mint(bob, DEPOSIT * 3);

        vm.prank(alice);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pool), type(uint256).max);
    }

    // ── Helpers ──

    function _shieldedId(address user) internal view returns (bytes32) {
        return sa.computeShieldedId(user);
    }

    function _deposit(address user, uint256 amount, uint256 lock) internal {
        vm.prank(user);
        pool.deposit(amount, lock);
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    function test_constructor_setsImmutables() public view {
        assertEq(address(pool.savingsAccount()), address(sa));
        assertEq(address(pool.yieldRouter()), address(router));
        assertEq(address(pool.usdc()), address(usdc));
        assertEq(pool.circle(), circleAddr);
        assertEq(pool.governance(), gov);
        assertEq(pool.coverageRateBps(), RATE_BPS);
    }

    // ──────────────────────────────────────────────
    // Deposit
    // ──────────────────────────────────────────────

    function test_deposit_emitsEvent() public {
        bytes32 aliceId = _shieldedId(alice);
        vm.expectEmit(true, false, false, false);
        emit Deposited(aliceId, DEPOSIT, 30 days, DEPOSIT);
        _deposit(alice, DEPOSIT, 30 days);
    }

    function test_deposit_routesToYieldRouter() public {
        _deposit(alice, DEPOSIT, 30 days);
        assertEq(router.totalAllocated(), DEPOSIT);
        assertEq(usdc.balanceOf(address(pool)), 0, "pool should hold no USDC directly");
    }

    function test_deposit_mintsPoolShares_firstDepositor() public {
        _deposit(alice, DEPOSIT, 30 days);
        assertEq(pool.poolShares(_shieldedId(alice)), DEPOSIT);
        assertEq(pool.totalPoolShares(), DEPOSIT);
    }

    function test_deposit_mintsPoolShares_secondDepositor_sameRatio() public {
        _deposit(alice, DEPOSIT, 30 days);
        _deposit(bob, DEPOSIT, 30 days);

        // 1:1 exchange rate in mock → both get equal shares
        assertEq(pool.poolShares(_shieldedId(alice)), DEPOSIT);
        assertEq(pool.poolShares(_shieldedId(bob)), DEPOSIT);
        assertEq(pool.totalPoolShares(), DEPOSIT * 2);
    }

    function test_deposit_revertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(SafetyNetPool.ZeroAmount.selector);
        pool.deposit(0, 30 days);
    }

    function test_deposit_multipleDeposits_accumulateShares() public {
        _deposit(alice, DEPOSIT, 30 days);
        _deposit(alice, DEPOSIT, 30 days);

        assertEq(pool.poolShares(_shieldedId(alice)), DEPOSIT * 2);
    }

    // ──────────────────────────────────────────────
    // View functions — getAvailableCapital / getWithdrawable
    // ──────────────────────────────────────────────

    function test_getAvailableCapital_equalsTotal_whenNothingDeployed() public {
        _deposit(alice, DEPOSIT, 30 days);
        assertEq(pool.getAvailableCapital(), DEPOSIT);
    }

    function test_getAvailableCapital_decreasesAfterCoverSlot() public {
        _deposit(alice, DEPOSIT, 30 days);

        vm.prank(circleAddr);
        pool.coverSlot(0, 0, 200e6);

        assertEq(pool.getAvailableCapital(), DEPOSIT - 200e6);
    }

    function test_getWithdrawable_fullBalance_whenNothingDeployed() public {
        _deposit(alice, DEPOSIT, 30 days);
        assertEq(pool.getWithdrawable(_shieldedId(alice)), DEPOSIT);
    }

    function test_getWithdrawable_proportional_twoDepositors() public {
        _deposit(alice, DEPOSIT, 30 days);
        _deposit(bob, DEPOSIT * 2, 30 days);

        // Alice: 1/3 of pool, Bob: 2/3
        assertEq(pool.getWithdrawable(_shieldedId(alice)), DEPOSIT);
        assertEq(pool.getWithdrawable(_shieldedId(bob)), DEPOSIT * 2);
    }

    function test_getWithdrawable_reducedWhenDeployed() public {
        _deposit(alice, DEPOSIT, 30 days);

        vm.prank(circleAddr);
        pool.coverSlot(0, 0, 400e6);

        // Available = 600, alice has 100% of shares → withdrawable = 600
        assertEq(pool.getWithdrawable(_shieldedId(alice)), DEPOSIT - 400e6);
    }

    function test_getWithdrawable_zeroForNoPosition() public view {
        assertEq(pool.getWithdrawable(_shieldedId(alice)), 0);
    }

    // ──────────────────────────────────────────────
    // Withdraw
    // ──────────────────────────────────────────────

    function test_withdraw_transfersUSDC() public {
        _deposit(alice, DEPOSIT, 30 days);

        uint256 before = usdc.balanceOf(alice);
        vm.prank(alice);
        pool.withdraw(DEPOSIT);
        assertEq(usdc.balanceOf(alice), before + DEPOSIT);
    }

    function test_withdraw_burnsPoolShares() public {
        _deposit(alice, DEPOSIT, 30 days);

        vm.prank(alice);
        pool.withdraw(DEPOSIT);

        assertEq(pool.poolShares(_shieldedId(alice)), 0);
        assertEq(pool.totalPoolShares(), 0);
        assertEq(pool.totalYRShares(), 0);
    }

    function test_withdraw_emitsEvent() public {
        _deposit(alice, DEPOSIT, 30 days);

        vm.expectEmit(true, false, false, false);
        emit Withdrawn(_shieldedId(alice), DEPOSIT, DEPOSIT);
        vm.prank(alice);
        pool.withdraw(DEPOSIT);
    }

    function test_withdraw_partialAmount() public {
        _deposit(alice, DEPOSIT, 0);

        vm.prank(alice);
        pool.withdraw(500e6);

        assertEq(pool.getWithdrawable(_shieldedId(alice)), 500e6);
        assertEq(usdc.balanceOf(alice), DEPOSIT * 3 - DEPOSIT + 500e6);
    }

    function test_withdraw_revertsOnZeroAmount() public {
        _deposit(alice, DEPOSIT, 0);

        vm.prank(alice);
        vm.expectRevert(SafetyNetPool.ZeroAmount.selector);
        pool.withdraw(0);
    }

    function test_withdraw_revertsIfExceedsWithdrawable() public {
        _deposit(alice, DEPOSIT, 0);

        vm.prank(circleAddr);
        pool.coverSlot(0, 0, DEPOSIT);  // deploy all capital

        // Nothing available
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(
            SafetyNetPool.InsufficientWithdrawable.selector, 0, 1
        ));
        pool.withdraw(1);
    }

    function test_withdraw_revertsIfNoPosition() public {
        vm.prank(alice);
        vm.expectRevert(SafetyNetPool.NoPosition.selector);
        pool.withdraw(100e6);
    }

    // ──────────────────────────────────────────────
    // coverSlot (ICircleBuffer)
    // ──────────────────────────────────────────────

    function test_coverSlot_recordsCoverage() public {
        _deposit(alice, DEPOSIT, 0);

        vm.expectEmit(true, true, false, true);
        emit SlotCovered(1, 3, 200e6);
        vm.prank(circleAddr);
        pool.coverSlot(1, 3, 200e6);

        (uint256 amount, uint256 ts) = pool.slotCoverages(1, 3);
        assertEq(amount, 200e6);
        assertGt(ts, 0);
        assertEq(pool.totalDeployed(), 200e6);
    }

    function test_coverSlot_revertsIfInsufficientCapital() public {
        // Pool is empty
        vm.prank(circleAddr);
        vm.expectRevert(abi.encodeWithSelector(
            SafetyNetPool.InsufficientAvailableCapital.selector, 0, 200e6
        ));
        pool.coverSlot(1, 0, 200e6);
    }

    function test_coverSlot_revertsIfNotCircle() public {
        _deposit(alice, DEPOSIT, 0);

        vm.prank(alice);
        vm.expectRevert(SafetyNetPool.OnlyCircle.selector);
        pool.coverSlot(1, 0, 200e6);
    }

    // ──────────────────────────────────────────────
    // releaseSlot (ICircleBuffer)
    // ──────────────────────────────────────────────

    function test_releaseSlot_restoresAvailableCapital() public {
        _deposit(alice, DEPOSIT, 0);

        vm.prank(circleAddr);
        pool.coverSlot(1, 5, 300e6);
        assertEq(pool.getAvailableCapital(), DEPOSIT - 300e6);

        vm.expectEmit(true, true, false, true);
        emit SlotReleased(1, 5, 300e6);
        vm.prank(circleAddr);
        pool.releaseSlot(1, 5);

        assertEq(pool.getAvailableCapital(), DEPOSIT);
        assertEq(pool.totalDeployed(), 0);
        (uint256 amount,) = pool.slotCoverages(1, 5);
        assertEq(amount, 0);
    }

    function test_releaseSlot_revertsIfSlotNotCovered() public {
        vm.prank(circleAddr);
        vm.expectRevert(abi.encodeWithSelector(
            SafetyNetPool.SlotNotCovered.selector, 0, 0
        ));
        pool.releaseSlot(0, 0);
    }

    function test_releaseSlot_revertsIfNotCircle() public {
        _deposit(alice, DEPOSIT, 0);

        vm.prank(circleAddr);
        pool.coverSlot(0, 0, 100e6);

        vm.prank(alice);
        vm.expectRevert(SafetyNetPool.OnlyCircle.selector);
        pool.releaseSlot(0, 0);
    }

    // ──────────────────────────────────────────────
    // Multiple slots / coverage accounting
    // ──────────────────────────────────────────────

    function test_multipleSlotsCovered_totalDeployedAccumulates() public {
        _deposit(alice, DEPOSIT, 0);

        vm.startPrank(circleAddr);
        pool.coverSlot(0, 0, 100e6);
        pool.coverSlot(0, 1, 200e6);
        pool.coverSlot(1, 0, 300e6);
        vm.stopPrank();

        assertEq(pool.totalDeployed(), 600e6);
        assertEq(pool.getAvailableCapital(), DEPOSIT - 600e6);
    }

    function test_releaseAllSlots_fullyRestoresCapital() public {
        _deposit(alice, DEPOSIT, 0);

        vm.startPrank(circleAddr);
        pool.coverSlot(0, 0, 100e6);
        pool.coverSlot(0, 1, 200e6);
        pool.releaseSlot(0, 0);
        pool.releaseSlot(0, 1);
        vm.stopPrank();

        assertEq(pool.totalDeployed(), 0);
        assertEq(pool.getAvailableCapital(), DEPOSIT);
    }

    // ──────────────────────────────────────────────
    // Governance
    // ──────────────────────────────────────────────

    function test_setCoverageRate_byGovernance() public {
        vm.expectEmit(false, false, false, true);
        emit CoverageRateUpdated(RATE_BPS, 300);
        vm.prank(gov);
        pool.setCoverageRate(300);

        assertEq(pool.coverageRateBps(), 300);
    }

    function test_setCoverageRate_revertsIfNotGovernance() public {
        vm.prank(alice);
        vm.expectRevert(SafetyNetPool.OnlyGovernance.selector);
        pool.setCoverageRate(300);
    }

    // ──────────────────────────────────────────────
    // getPositionValue
    // ──────────────────────────────────────────────

    function test_getPositionValue_equalsDeposit_noYield() public {
        _deposit(alice, DEPOSIT, 0);
        assertEq(pool.getPositionValue(_shieldedId(alice)), DEPOSIT);
    }

    function test_getPositionValue_proRata_twoDepositors() public {
        _deposit(alice, DEPOSIT, 0);
        _deposit(bob, DEPOSIT * 3, 0);

        assertEq(pool.getPositionValue(_shieldedId(alice)), DEPOSIT);
        assertEq(pool.getPositionValue(_shieldedId(bob)), DEPOSIT * 3);
    }

    function test_getPositionValue_zeroForNoPosition() public view {
        assertEq(pool.getPositionValue(_shieldedId(alice)), 0);
    }

    // ──────────────────────────────────────────────
    // AC-006-3: pool depth not required for self-funded circles
    // ──────────────────────────────────────────────

    function test_emptyPool_doesNotAffectSelfFundedCircles() public view {
        // Pool has zero capital; self-funded circles (no coverSlot calls) are unaffected
        assertEq(pool.getAvailableCapital(), 0);
        assertEq(pool.totalDeployed(), 0);
    }
}
