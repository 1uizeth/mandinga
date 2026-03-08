// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {SavingsCircle} from "../../src/core/SavingsCircle.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {ISafetyNetPool} from "../../src/interfaces/ISafetyNetPool.sol";
import {MockSavingsAccount} from "../mocks/MockSavingsAccount.sol";
import {MockVRFCoordinatorV2Plus} from "../mocks/MockVRFCoordinatorV2Plus.sol";
import {MockSafetyNetPool} from "../mocks/MockSafetyNetPool.sol";

contract SavingsCircleTest is Test {
    // ── Local event copies for vm.expectEmit ──
    event CircleCreated(uint256 indexed circleId, uint256 poolSize, uint16 memberCount, uint256 roundDuration);
    event MemberJoined(uint256 indexed circleId, uint16 slot, bytes32 shieldedId);
    event CircleActivated(uint256 indexed circleId, uint256 firstRoundTimestamp);
    event RoundRequested(uint256 indexed circleId, uint256 vrfRequestId);
    event RoundExecuted(uint256 indexed circleId, uint16 roundNumber);
    event RoundSkipped(uint256 indexed circleId, uint16 roundNumber);
    event CircleCompleted(uint256 indexed circleId);
    event MemberPaused(uint256 indexed circleId, uint16 slot);
    event MemberResumed(uint256 indexed circleId, uint16 slot);

    MockSavingsAccount internal sa;
    MockVRFCoordinatorV2Plus internal vrf;
    MockSafetyNetPool internal buf;
    SavingsCircle internal sc;

    // Test actors
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal eve = makeAddr("eve");

    // Default circle params
    uint256 internal constant POOL = 1_000e6;   // 1000 USDC
    uint8 internal constant N = 5;
    uint256 internal constant CONTRIB = POOL / N; // 200 USDC
    uint256 internal constant ROUND_DUR = 5 minutes;

    bytes32 internal constant KEY_HASH = bytes32(uint256(1));
    uint256 internal constant SUB_ID = 1;

    address[] internal members5 = [alice, bob, carol, dave, eve];

    function setUp() public {
        sa = new MockSavingsAccount();
        vrf = new MockVRFCoordinatorV2Plus();
        buf = new MockSafetyNetPool();
        buf.setAvailableCapital(type(uint256).max); // pool always has capital in unit tests
        sc = new SavingsCircle(
            ISavingsAccount(address(sa)),
            ISafetyNetPool(address(buf)),
            address(vrf),
            KEY_HASH,
            SUB_ID
        );

        // Give each actor enough withdrawable balance
        for (uint256 i = 0; i < members5.length; i++) {
            bytes32 id = sa.computeShieldedId(members5[i]);
            sa.setPosition(id, CONTRIB * 2, 0);  // balance = 2×contrib, obligation = 0
        }
    }

    // ──────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────

    function _createDefault() internal returns (uint256 circleId) {
        circleId = sc.createCircle(POOL, N, ROUND_DUR, 0);
    }

    function _joinAll(uint256 circleId, address[] memory actors) internal {
        for (uint256 i = 0; i < actors.length; i++) {
            vm.prank(actors[i]);
            sc.joinCircle(circleId);
        }
    }

    function _executeAndFulfill(uint256 circleId, uint256 randomWord) internal {
        sc.executeRound(circleId);
        uint256 reqId = vrf.getLastRequestId();
        vrf.fulfillRequest(reqId, randomWord);
    }

    function _shieldedId(address user) internal view returns (bytes32) {
        return sa.computeShieldedId(user);
    }

    // ──────────────────────────────────────────────
    // createCircle
    // ──────────────────────────────────────────────

    function test_createCircle_succeeds() public {
        vm.expectEmit(true, false, false, true);
        emit CircleCreated(0, POOL, N, ROUND_DUR);
        uint256 id = sc.createCircle(POOL, N, ROUND_DUR, 0);
        assertEq(id, 0);

        (uint256 poolSize, uint16 memberCount,,,,,,,  SavingsCircle.CircleStatus status,) = sc.circles(id);
        assertEq(poolSize, POOL);
        assertEq(memberCount, N);
        assertEq(uint8(status), uint8(SavingsCircle.CircleStatus.FORMING));
    }

    function test_createCircle_revertsZeroPoolSize() public {
        vm.expectRevert(SavingsCircle.InvalidPoolSize.selector);
        sc.createCircle(0, N, ROUND_DUR, 0);
    }

    /// @dev memberCount < MIN_MEMBERS (2) reverts
    function test_createCircle_revertsLowMemberCount() public {
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.InvalidMemberCount.selector, uint16(1), sc.MIN_MEMBERS(), sc.MAX_MEMBERS()
        ));
        sc.createCircle(POOL, 1, ROUND_DUR, 0);
    }

    /// @dev memberCount > MAX_MEMBERS (1000) reverts
    function test_createCircle_revertsHighMemberCount() public {
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.InvalidMemberCount.selector, uint16(1001), sc.MIN_MEMBERS(), sc.MAX_MEMBERS()
        ));
        sc.createCircle(POOL, 1001, ROUND_DUR, 0);
    }

    /// @dev roundDuration = 0 is the only invalid duration (MIN = 1 minute for testnet)
    function test_createCircle_revertsZeroDuration() public {
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.InvalidRoundDuration.selector,
            0, sc.MIN_ROUND_DURATION(), sc.MAX_ROUND_DURATION()
        ));
        sc.createCircle(POOL, N, 0, 0);
    }

    /// @dev Any duration >= 1 minute is accepted — including sub-7-day values for testnet
    function test_createCircle_acceptsShortDurationForTestnet() public {
        uint256 id = sc.createCircle(POOL, N, 1 minutes, 0);
        (,,, uint256 roundDuration,,,,,,) = sc.circles(id);
        assertEq(roundDuration, 1 minutes);
    }

    /// @dev CHK009: poolSize not divisible by memberCount
    function test_createCircle_revertsIndivisiblePool() public {
        // 1_000_003 ends in 3 — not divisible by 5
        uint256 badPool = 1_000_003;
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.PoolSizeNotDivisible.selector, badPool, N
        ));
        sc.createCircle(badPool, N, ROUND_DUR, 0);
    }

    // ──────────────────────────────────────────────
    // joinCircle → all slots filled → ACTIVE
    // ──────────────────────────────────────────────

    function test_joinCircle_fillsSlots() public {
        uint256 id = _createDefault();

        for (uint8 i = 0; i < N; i++) {
            vm.expectEmit(true, false, false, true);
            emit MemberJoined(id, uint16(i), _shieldedId(members5[i]));
            vm.prank(members5[i]);
            sc.joinCircle(id);

            // struct: poolSize(0) memberCount(1) contrib(2) roundDur(3) nextTs(4) filledSlots(5) ...
            (,,,,, uint16 filledSlots,,,,) = sc.circles(id);
            assertEq(filledSlots, i + 1);
        }

        // Last join activates — struct: poolSize(0) memberCount(1) contrib(2) roundDur(3)
        //   nextTs(4) filledSlots(5) roundsCompleted(6) pendingVrfReq(7) status(8)
        (,,,,, uint16 slots,,,  SavingsCircle.CircleStatus status,) = sc.circles(id);
        assertEq(slots, N);
        assertEq(uint8(status), uint8(SavingsCircle.CircleStatus.ACTIVE));
    }

    function test_joinCircle_setsObligation() public {
        uint256 id = _createDefault();
        vm.prank(alice);
        sc.joinCircle(id);

        assertEq(sa.getCircleObligation(_shieldedId(alice)), CONTRIB);
    }

    function test_joinCircle_revertsIfNotForming() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);  // activates

        address extra = makeAddr("extra");
        bytes32 extraId = sa.computeShieldedId(extra);
        sa.setPosition(extraId, CONTRIB * 2, 0);

        vm.prank(extra);
        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.CircleNotForming.selector, id));
        sc.joinCircle(id);
    }

    function test_joinCircle_revertsIfFull() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);  // fills all 5 slots

        // Activate a fresh circle that's still FORMING at id 0 — already active
        // Test: try to join the now-active circle
        vm.prank(makeAddr("extra"));
        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.CircleNotForming.selector, id));
        sc.joinCircle(id);
    }

    function test_joinCircle_revertsIfAlreadyMember() public {
        uint256 id = _createDefault();
        vm.prank(alice);
        sc.joinCircle(id);

        bytes32 aliceId = _shieldedId(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.AlreadyMember.selector, id, aliceId));
        sc.joinCircle(id);
    }

    function test_joinCircle_revertsIfInsufficientBalance() public {
        uint256 id = _createDefault();

        address poor = makeAddr("poor");
        bytes32 poorId = sa.computeShieldedId(poor);
        sa.setPosition(poorId, CONTRIB - 1, 0);  // 1 unit short

        vm.prank(poor);
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.InsufficientBalance.selector, CONTRIB - 1, CONTRIB
        ));
        sc.joinCircle(id);
    }

    // ──────────────────────────────────────────────
    // executeRound
    // ──────────────────────────────────────────────

    function test_executeRound_revertsBeforeTimestamp() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);

        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.RoundNotDue.selector, nextTs, block.timestamp
        ));
        sc.executeRound(id);
    }

    function test_executeRound_requestsVRFAfterTimestamp() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);
        vm.warp(nextTs);

        vm.expectEmit(true, false, false, false);
        emit RoundRequested(id, 1);
        sc.executeRound(id);

        (,,,,,,,uint256 pendingReq,,) = sc.circles(id);
        assertEq(pendingReq, 1);
    }

    function test_executeRound_revertsIfVrfPending() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);
        vm.warp(nextTs);

        sc.executeRound(id);  // first call — VRF pending

        vm.warp(block.timestamp + ROUND_DUR);  // time passes but VRF not fulfilled

        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.VrfRequestPending.selector, id, 1));
        sc.executeRound(id);
    }

    // ──────────────────────────────────────────────
    // VRF callback — correct member selected → payout
    // ──────────────────────────────────────────────

    function test_vrfCallback_selectsMemberAndProcessesPayout() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);
        vm.warp(nextTs);
        sc.executeRound(id);
        uint256 reqId = vrf.getLastRequestId();

        // Phase 1: VRF callback marks winner (slot 0 = alice for seed 0)
        vm.expectEmit(true, false, false, true);
        emit RoundExecuted(id, 1);
        vrf.fulfillRequest(reqId, 0);

        // After Phase 1: payoutReceived and pendingPayout are set
        assertTrue(sc.payoutReceived(id, 0), "payoutReceived after VRF");
        assertTrue(sc.pendingPayout(id, 0), "pendingPayout after VRF");

        // Obligation and balance NOT yet updated (two-phase design)
        bytes32 aliceId = _shieldedId(alice);
        assertEq(sa.getCircleObligation(aliceId), CONTRIB, "obligation unchanged before claimPayout");

        // Phase 2: claimPayout settles the debt and credits balance
        vm.prank(alice);
        sc.claimPayout(id, 0);

        assertFalse(sc.pendingPayout(id, 0), "pendingPayout cleared after claim");
        assertEq(sa.getCircleObligation(aliceId), POOL, "obligation raised to poolSize");
        assertEq(sa.getPosition(aliceId).balance, CONTRIB * 2 + POOL, "balance credited");
    }

    function test_vrfCallback_selectedMemberCannotBeSelectedAgain() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);
        vm.warp(nextTs);

        // Round 1 → always picks slot 0 (randomWord % 5 == 0 maps to eligible[0])
        _executeAndFulfill(id, 0);
        assertTrue(sc.payoutReceived(id, 0));  // slot 0 paid

        // Round 2 → eligible count is 4, randomWord=0 → eligible[0] = slot 1
        vm.warp(block.timestamp + ROUND_DUR);
        _executeAndFulfill(id, 0);
        assertTrue(sc.payoutReceived(id, 1));  // slot 1 paid, slot 0 still excluded
    }

    // ──────────────────────────────────────────────
    // Pause / resume
    // ──────────────────────────────────────────────

    function test_pausedMemberExcludedFromSelection() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        // Drain alice's balance so she's below obligation
        bytes32 aliceId = _shieldedId(alice);
        sa.setPosition(aliceId, CONTRIB - 1, CONTRIB);  // balance < obligation

        sc.checkAndPause(id, 0);
        assertTrue(sc.positionPaused(id, 0));
        assertEq(buf.coverSlotCallCount(), 1);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);
        vm.warp(nextTs);

        // randomWord=0 → eligible[0] is slot 1 (slot 0 paused, 4 eligible)
        _executeAndFulfill(id, 0);
        assertFalse(sc.payoutReceived(id, 0), "paused slot should not receive payout");
        assertTrue(sc.payoutReceived(id, 1));
    }

    function test_checkAndPause_noopIfSufficientBalance() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        // alice has balance >= obligation
        sc.checkAndPause(id, 0);  // should not emit MemberPaused
        assertFalse(sc.positionPaused(id, 0));
        assertEq(buf.coverSlotCallCount(), 0);
    }

    function test_checkAndPause_revertsIfAlreadyPaused() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        bytes32 aliceId = _shieldedId(alice);
        sa.setPosition(aliceId, CONTRIB - 1, CONTRIB);

        sc.checkAndPause(id, 0);

        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.MemberAlreadyPaused.selector, id, 0));
        sc.checkAndPause(id, 0);
    }

    function test_resumePausedMember_works() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        bytes32 aliceId = _shieldedId(alice);
        sa.setPosition(aliceId, CONTRIB - 1, CONTRIB);
        sc.checkAndPause(id, 0);

        // Restore alice's balance
        sa.setPosition(aliceId, CONTRIB * 2, CONTRIB);

        vm.expectEmit(true, false, false, true);
        emit MemberResumed(id, 0);
        sc.resumePausedMember(id, 0);

        assertFalse(sc.positionPaused(id, 0));
        assertEq(buf.releaseSlotCallCount(), 1);
    }

    function test_resumePausedMember_revertsIfNotPaused() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.MemberNotPaused.selector, id, 0));
        sc.resumePausedMember(id, 0);
    }

    // ──────────────────────────────────────────────
    // CHK028 — no eligible members → RoundSkipped
    // ──────────────────────────────────────────────

    function test_allMembersPaused_roundSkipped() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        // Drain all members' balances
        for (uint16 i = 0; i < N; i++) {
            bytes32 mid = sc.getMember(id, i);
            sa.setPosition(mid, 0, CONTRIB);
            sc.checkAndPause(id, i);
        }
        assertEq(sc.getEligibleCount(id), 0);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);
        vm.warp(nextTs);

        sc.executeRound(id);
        uint256 reqId = vrf.getLastRequestId();

        vm.expectEmit(true, false, false, true);
        emit RoundSkipped(id, 0);
        vrf.fulfillRequest(reqId, 0);

        // No payout processed
        (,,,,,, uint16 roundsCompleted,,,) = sc.circles(id);
        assertEq(roundsCompleted, 0);
    }

    // ──────────────────────────────────────────────
    // Circle completion
    // ──────────────────────────────────────────────

    function test_circleCompletesAfterAllRounds() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);

        // Run all 5 rounds, always pick slot 0 first eligible
        for (uint8 round = 0; round < N; round++) {
            vm.warp(nextTs + round * ROUND_DUR);
            _executeAndFulfill(id, 0);
        }

        (,,,,,,,, SavingsCircle.CircleStatus status,) = sc.circles(id);
        assertEq(uint8(status), uint8(SavingsCircle.CircleStatus.COMPLETED));
    }

    function test_circleCompletion_releasesAllObligations() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        (,,,,uint256 nextTs,,,,, ) = sc.circles(id);

        for (uint8 round = 0; round < N; round++) {
            vm.warp(nextTs + round * ROUND_DUR);
            _executeAndFulfill(id, 0);
        }

        for (uint16 i = 0; i < N; i++) {
            bytes32 mid = sc.getMember(id, i);
            assertEq(sa.getCircleObligation(mid), 0, "obligation not released");
        }
    }

    // ──────────────────────────────────────────────
    // View helpers
    // ──────────────────────────────────────────────

    function test_getEligibleCount() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        assertEq(sc.getEligibleCount(id), N);

        // Pause slot 0
        bytes32 aliceId = _shieldedId(alice);
        sa.setPosition(aliceId, 0, CONTRIB);
        sc.checkAndPause(id, 0);
        assertEq(sc.getEligibleCount(id), N - 1);
    }

    function test_getMembers_returnsAllShieldedIds() public {
        uint256 id = _createDefault();
        _joinAll(id, members5);

        bytes32[] memory mems = sc.getMembers(id);
        assertEq(mems.length, N);
        for (uint256 i = 0; i < N; i++) {
            assertEq(mems[i], _shieldedId(members5[i]));
        }
    }
}
