// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SafetyNetPool} from "../../src/core/SafetyNetPool.sol";
import {SavingsCircle} from "../../src/core/SavingsCircle.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";
import {ISafetyNetPool} from "../../src/interfaces/ISafetyNetPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockYieldRouter} from "../mocks/MockYieldRouter.sol";
import {MockSavingsAccount} from "../mocks/MockSavingsAccount.sol";
import {MockVRFCoordinatorV2Plus} from "../mocks/MockVRFCoordinatorV2Plus.sol";

/// @notice Integration tests for SafetyNetPool + SavingsCircle cooperation.
///
/// Scenario: 3-member circle. One member's balance dips below obligation →
/// pool covers their slot. Member tops up → pool releases slot.
/// Circle completes; pool capital is fully restored.
contract PoolCoverageIntegrationTest is Test {
    // ── Fixtures ──
    MockUSDC internal usdc;
    MockYieldRouter internal router;
    MockSavingsAccount internal sa;
    MockVRFCoordinatorV2Plus internal vrf;
    SafetyNetPool internal pool;
    SavingsCircle internal sc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal poolDepositor = makeAddr("poolDepositor");
    address internal gov = makeAddr("gov");

    bytes32 internal constant KEY_HASH = bytes32(uint256(1));
    uint256 internal constant SUB_ID = 1;

    uint256 internal constant POOL_SIZE = 300e6;    // $300 USDC
    uint16 internal constant MEMBER_COUNT = 3;
    uint256 internal constant CONTRIBUTION = 100e6; // $100 per member
    uint256 internal constant ROUND_DUR = 5 minutes;

    uint256 internal circleId;

    function setUp() public {
        usdc = new MockUSDC();
        router = new MockYieldRouter(address(usdc));
        sa = new MockSavingsAccount();
        vrf = new MockVRFCoordinatorV2Plus();

        // Deploy SafetyNetPool with the address SavingsCircle will occupy at next nonce
        address futureCircle = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        pool = new SafetyNetPool(
            ISavingsAccount(address(sa)),
            IYieldRouter(address(router)),
            usdc,
            futureCircle,
            gov,
            500 // 5% annual coverage rate
        );
        sc = new SavingsCircle(
            ISavingsAccount(address(sa)),
            ISafetyNetPool(address(pool)),
            address(vrf),
            KEY_HASH,
            SUB_ID
        );
        assertEq(address(sc), futureCircle, "address prediction mismatch");

        // Fund pool depositor and pool
        usdc.mint(poolDepositor, 500e6);
        vm.prank(poolDepositor);
        usdc.approve(address(pool), type(uint256).max);

        // Give pool depositor a shieldedId via MockSavingsAccount
        // (MockSavingsAccount computes keccak256(user, 0) by default — no explicit registration needed)

        // Set up member positions in MockSavingsAccount
        _registerMember(alice, CONTRIBUTION);
        _registerMember(bob, CONTRIBUTION);
        _registerMember(carol, CONTRIBUTION);

        // Create and fill the circle
        circleId = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, 0);
        vm.prank(alice); sc.joinCircle(circleId);
        vm.prank(bob);   sc.joinCircle(circleId);
        vm.prank(carol); sc.joinCircle(circleId);
        // circle is now ACTIVE (all 3 slots filled)
    }

    // ── Helpers ──

    function _registerMember(address user, uint256 balance) internal {
        bytes32 id = sa.computeShieldedId(user);
        // obligation starts at 0; joinCircle will call setCircleObligation to lock CONTRIBUTION
        sa.setPosition(id, balance, 0);
    }

    function _doRound(uint256 cId, uint256 randomWord) internal {
        (, , , , uint256 nextTs, , , , ,) = sc.circles(cId);
        vm.warp(nextTs);
        sc.executeRound(cId);
        uint256 reqId = vrf.getLastRequestId();
        vrf.fulfillRequest(reqId, randomWord);
    }

    // ──────────────────────────────────────────────
    // Test 1 — Pool deposit → cover → release lifecycle
    // ──────────────────────────────────────────────

    /// @notice Pool depositor funds pool; member A's balance dips; pool covers slot;
    ///         member A tops up; pool releases slot. All capital accounting intact.
    function test_coverAndRelease_lifecycle() public {
        // 1. Pool depositor funds pool
        vm.prank(poolDepositor);
        pool.deposit(200e6, 30 days);
        assertEq(pool.getAvailableCapital(), 200e6);

        // 2. Alice's balance dips below her obligation (simulates missed contribution)
        bytes32 aliceId = sa.computeShieldedId(alice);
        sa.setPosition(aliceId, 50e6, CONTRIBUTION);  // balance < obligation

        // 3. Anyone can call checkAndPause
        uint16 aliceSlot = 0; // alice joined first
        sc.checkAndPause(circleId, aliceSlot);

        assertTrue(sc.positionPaused(circleId, aliceSlot), "alice should be paused");
        assertEq(pool.totalDeployed(), CONTRIBUTION,     "pool should have deployed alice's contribution");
        assertEq(pool.getAvailableCapital(), 200e6 - CONTRIBUTION);

        (uint256 covAmt, ) = pool.slotCoverages(circleId, aliceSlot);
        assertEq(covAmt, CONTRIBUTION, "slot coverage amount mismatch");

        // 4. Alice tops up — must have withdrawable (balance - obligation) >= contributionPerMember
        //    → balance >= 2 * CONTRIBUTION
        sa.setPosition(aliceId, CONTRIBUTION * 2 + 1e6, CONTRIBUTION);

        // 5. Resume alice
        sc.resumePausedMember(circleId, aliceSlot);

        assertFalse(sc.positionPaused(circleId, aliceSlot), "alice should no longer be paused");
        assertEq(pool.totalDeployed(), 0,      "pool deployment should be released");
        assertEq(pool.getAvailableCapital(), 200e6); // fully restored
    }

    // ──────────────────────────────────────────────
    // Test 2 — Pool capital is insufficient → coverSlot reverts
    // ──────────────────────────────────────────────

    /// @notice If pool has insufficient capital, checkAndPause reverts (capital check is strict).
    function test_checkAndPause_revertsIfPoolEmpty() public {
        // Pool is empty
        bytes32 aliceId = sa.computeShieldedId(alice);
        sa.setPosition(aliceId, 50e6, CONTRIBUTION);

        vm.expectRevert(abi.encodeWithSelector(
            SafetyNetPool.InsufficientAvailableCapital.selector, 0, CONTRIBUTION
        ));
        sc.checkAndPause(circleId, 0);
    }

    // ──────────────────────────────────────────────
    // Test 3 — Multiple paused slots, sequential release
    // ──────────────────────────────────────────────

    function test_multiplePausedSlots_sequentialRelease() public {
        vm.prank(poolDepositor);
        pool.deposit(500e6, 90 days);

        // Both alice and bob dip below obligation
        bytes32 aliceId = sa.computeShieldedId(alice);
        bytes32 bobId = sa.computeShieldedId(bob);
        sa.setPosition(aliceId, 10e6, CONTRIBUTION);
        sa.setPosition(bobId, 10e6, CONTRIBUTION);

        sc.checkAndPause(circleId, 0); // alice
        sc.checkAndPause(circleId, 1); // bob

        assertEq(pool.totalDeployed(), CONTRIBUTION * 2);
        assertEq(pool.getAvailableCapital(), 500e6 - CONTRIBUTION * 2);

        // Alice resumes — needs withdrawable (balance - obligation) >= CONTRIBUTION
        sa.setPosition(aliceId, CONTRIBUTION * 2 + 1e6, CONTRIBUTION);
        sc.resumePausedMember(circleId, 0);
        assertEq(pool.totalDeployed(), CONTRIBUTION);

        // Bob resumes — same requirement
        sa.setPosition(bobId, CONTRIBUTION * 2 + 1e6, CONTRIBUTION);
        sc.resumePausedMember(circleId, 1);
        assertEq(pool.totalDeployed(), 0);

        // Full capital available again
        assertEq(pool.getAvailableCapital(), 500e6);
    }

    // ──────────────────────────────────────────────
    // Test 4 — Pool depositor can withdraw available capital
    // ──────────────────────────────────────────────

    function test_poolDepositor_canWithdraw_undeployedCapital() public {
        vm.prank(poolDepositor);
        pool.deposit(200e6, 30 days);

        // Deploy half to cover a slot
        bytes32 aliceId = sa.computeShieldedId(alice);
        sa.setPosition(aliceId, 10e6, CONTRIBUTION);
        sc.checkAndPause(circleId, 0);
        assertEq(pool.totalDeployed(), CONTRIBUTION);

        bytes32 depositorId = sa.computeShieldedId(poolDepositor);
        uint256 withdrawable = pool.getWithdrawable(depositorId);
        assertEq(withdrawable, 200e6 - CONTRIBUTION);

        uint256 balBefore = usdc.balanceOf(poolDepositor);
        vm.prank(poolDepositor);
        pool.withdraw(withdrawable);

        assertEq(usdc.balanceOf(poolDepositor), balBefore + withdrawable);
    }

    // ──────────────────────────────────────────────
    // Test 5 — Full circle + pool coverage round trip
    // ──────────────────────────────────────────────

    /// @notice Full 3-round circle lifecycle with one paused member who recovers
    ///         before her round. Pool capital accounting is correct throughout.
    function test_fullCircle_withPauseAndResume() public {
        vm.prank(poolDepositor);
        pool.deposit(500e6, 365 days);
        bytes32 depositorId = sa.computeShieldedId(poolDepositor);

        // --- Round 1: alice paused, bob selected ---
        bytes32 aliceId = sa.computeShieldedId(alice);
        sa.setPosition(aliceId, 10e6, CONTRIBUTION);
        sc.checkAndPause(circleId, 0); // alice slot 0

        // Execute round 1 — select slot 1 (bob) via random word = 0 mod 2 eligible = index 0 = slot 1
        (, , , , uint256 nextTs, , , , ,) = sc.circles(circleId);
        vm.warp(nextTs);
        sc.executeRound(circleId);
        uint256 reqId1 = vrf.getLastRequestId();
        // Eligible slots: 1 (bob), 2 (carol). randomWord % 2 = 0 → slot 1 (bob)
        vrf.fulfillRequest(reqId1, 0);

        assertTrue(sc.payoutReceived(circleId, 1), "bob should have received payout");
        assertEq(pool.totalDeployed(), CONTRIBUTION); // alice still paused

        // --- Alice tops up and resumes ---
        // needs withdrawable (balance - obligation) >= CONTRIBUTION → balance >= 2 * CONTRIBUTION
        sa.setPosition(aliceId, CONTRIBUTION * 2 + 1e6, CONTRIBUTION);
        sc.resumePausedMember(circleId, 0);
        assertFalse(sc.positionPaused(circleId, 0));
        assertEq(pool.totalDeployed(), 0);

        // --- Round 2: alice and carol eligible, select alice ---
        (, , , , nextTs, , , , ,) = sc.circles(circleId);
        vm.warp(nextTs);
        sc.executeRound(circleId);
        uint256 reqId2 = vrf.getLastRequestId();
        // Eligible: slot 0 (alice), slot 2 (carol). randomWord % 2 = 0 → slot 0 (alice)
        vrf.fulfillRequest(reqId2, 0);

        assertTrue(sc.payoutReceived(circleId, 0), "alice should have received payout");

        // --- Round 3: only carol eligible ---
        (, , , , nextTs, , , , ,) = sc.circles(circleId);
        vm.warp(nextTs);
        sc.executeRound(circleId);
        uint256 reqId3 = vrf.getLastRequestId();
        vrf.fulfillRequest(reqId3, 0);

        assertTrue(sc.payoutReceived(circleId, 2), "carol should have received payout");

        (, , , , , , , , SavingsCircle.CircleStatus status,) = sc.circles(circleId);
        assertEq(uint8(status), uint8(SavingsCircle.CircleStatus.COMPLETED));

        // Pool capital fully intact (no coverage active at completion)
        assertEq(pool.totalDeployed(), 0);
        assertEq(pool.getPositionValue(depositorId), 500e6);
    }
}
