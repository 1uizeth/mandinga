// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SavingsCircle} from "../../src/core/SavingsCircle.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {ISafetyNetPool} from "../../src/interfaces/ISafetyNetPool.sol";
import {MockSavingsAccount} from "../mocks/MockSavingsAccount.sol";
import {MockVRFCoordinatorV2Plus} from "../mocks/MockVRFCoordinatorV2Plus.sol";
import {MockSafetyNetPool} from "../mocks/MockSafetyNetPool.sol";

/// @notice Unit tests for Task 003-02: minDepositPerRound feature in SavingsCircle.
contract MinDepositPerRoundTest is Test {
    // ── Events ──
    event MinInstallmentActivated(uint256 indexed circleId, bytes32 shieldedId);
    event MemberSelected(uint256 indexed circleId, uint16 slot, bytes32 shieldedId);

    MockSavingsAccount internal sa;
    MockVRFCoordinatorV2Plus internal vrf;
    MockSafetyNetPool internal pool;
    SavingsCircle internal sc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant POOL_SIZE = 300e6;      // $300 USDC
    uint16 internal constant MEMBER_COUNT = 3;
    uint256 internal constant CONTRIB = 100e6;         // $100 per member
    uint256 internal constant MIN_DEP = 50e6;          // $50 min installment
    uint256 internal constant GAP = CONTRIB - MIN_DEP; // $50 gap
    uint256 internal constant ROUND_DUR = 5 minutes;

    bytes32 internal constant KEY_HASH = bytes32(uint256(1));
    uint256 internal constant SUB_ID = 1;

    function setUp() public {
        sa = new MockSavingsAccount();
        vrf = new MockVRFCoordinatorV2Plus();
        pool = new MockSafetyNetPool();
        pool.setAvailableCapital(type(uint256).max);
        sc = new SavingsCircle(ISavingsAccount(address(sa)), ISafetyNetPool(address(pool)), address(vrf), KEY_HASH, SUB_ID);

        bytes32 idA = sa.computeShieldedId(alice);
        bytes32 idB = sa.computeShieldedId(bob);
        bytes32 idC = sa.computeShieldedId(carol);
        sa.setPosition(idA, CONTRIB * 2, 0);
        sa.setPosition(idB, CONTRIB * 2, 0);
        sa.setPosition(idC, CONTRIB * 2, 0);
    }

    // T018: createCircle accepts valid minDepositPerRound
    function test_createCircle_withMinDeposit_succeeds() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);
        (,,,,,,,,, uint256 stored) = sc.circles(id);
        assertEq(stored, MIN_DEP);
    }

    // T019: createCircle reverts when minDepositPerRound < MIN_MIN_DEPOSIT (1 USDC)
    function test_createCircle_minDepositTooLow_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.MinDepositTooLow.selector, 0.5e6, sc.MIN_MIN_DEPOSIT()
        ));
        sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, 0.5e6);
    }

    // T019: createCircle reverts when minDepositPerRound >= contributionPerMember
    function test_createCircle_minDepositEqualContrib_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.InvalidMinDeposit.selector, CONTRIB, CONTRIB
        ));
        sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, CONTRIB);
    }

    // T019: zero minDepositPerRound disables the feature
    function test_createCircle_zeroMinDeposit_disablesFeature() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, 0);
        (,,,,,,,,, uint256 stored) = sc.circles(id);
        assertEq(stored, 0, "feature disabled");
    }

    // T020: activateMinInstallment emits event and sets flag
    function test_activateMinInstallment_setsFlag() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);
        bytes32 aliceId = sa.computeShieldedId(alice);

        vm.expectEmit(true, false, false, true);
        emit MinInstallmentActivated(id, aliceId);

        vm.prank(alice);
        sc.activateMinInstallment(id);

        assertTrue(sc.usesMinInstallment(id, aliceId));
    }

    // T020: activateMinInstallment reverts if circle is not FORMING
    function test_activateMinInstallment_afterActivation_reverts() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);
        vm.prank(alice); sc.joinCircle(id);
        vm.prank(bob);   sc.joinCircle(id);
        vm.prank(carol); sc.joinCircle(id); // circle now ACTIVE

        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.CircleAlreadyActive.selector, id));
        vm.prank(alice);
        sc.activateMinInstallment(id);
    }

    // T020: activateMinInstallment reverts if minDepositPerRound == 0
    function test_activateMinInstallment_featureDisabled_reverts() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, 0);
        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.InvalidMinDeposit.selector, 0, CONTRIB));
        vm.prank(alice);
        sc.activateMinInstallment(id);
    }

    // T021: joinCircle with insufficient pool depth reverts
    function test_joinCircle_insufficientPoolDepth_reverts() public {
        pool.setAvailableCapital(0); // pool is empty
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);

        vm.prank(alice);
        sc.activateMinInstallment(id);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.InsufficientPoolDepth.selector,
            0,
            GAP * MEMBER_COUNT // required = (0+1) * gap * memberCount
        ));
        sc.joinCircle(id);
    }

    // T022: executeRound calls pool.coverGap for min-installment members
    function test_executeRound_callsCoverGap_forMinInstallmentMembers() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);

        vm.prank(alice); sc.activateMinInstallment(id);
        vm.prank(alice); sc.joinCircle(id);
        vm.prank(bob);   sc.joinCircle(id);
        vm.prank(carol); sc.joinCircle(id);

        (, , , , uint256 nextTs, , , , ,) = sc.circles(id);
        vm.warp(nextTs);
        sc.executeRound(id);

        assertEq(pool.coverGapCallCount(), 1, "should cover gap for alice (slot 0)");
        (, , bytes32 calledMemberId, uint256 calledGap) = pool.coverGapCalls(0);
        assertEq(calledGap, GAP);
        assertEq(calledMemberId, sa.computeShieldedId(alice));
    }

    // T023: executeRound does NOT call coverGap for non-min-installment members
    function test_executeRound_skipsNonMinInstallmentMembers() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);
        // nobody activates min installment
        vm.prank(alice); sc.joinCircle(id);
        vm.prank(bob);   sc.joinCircle(id);
        vm.prank(carol); sc.joinCircle(id);

        (, , , , uint256 nextTs, , , , ,) = sc.circles(id);
        vm.warp(nextTs);
        sc.executeRound(id);

        assertEq(pool.coverGapCallCount(), 0, "no gap calls for normal members");
    }

    // T025: two min-installment members — both gaps covered
    function test_coverGap_twoMinInstallmentMembers() public {
        pool.setAvailableCapital(type(uint256).max);
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);

        vm.prank(alice); sc.activateMinInstallment(id);
        vm.prank(bob);   sc.activateMinInstallment(id);
        vm.prank(alice); sc.joinCircle(id);
        vm.prank(bob);   sc.joinCircle(id);
        vm.prank(carol); sc.joinCircle(id);

        (, , , , uint256 nextTs, , , , ,) = sc.circles(id);
        vm.warp(nextTs);
        sc.executeRound(id);

        assertEq(pool.coverGapCallCount(), 2, "two gap covers (alice slot0, bob slot1)");
    }

    // T024: auto-pause when pool.coverGap reverts (InsufficientAvailableCapital)
    function test_executeRound_autoPause_whenCoverGapReverts() public {
        uint256 id = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);

        vm.prank(alice); sc.activateMinInstallment(id);
        vm.prank(alice); sc.joinCircle(id);
        vm.prank(bob);   sc.joinCircle(id);
        vm.prank(carol); sc.joinCircle(id);

        // Drain pool after joining (depth check already passed)
        pool.setAvailableCapital(0);
        pool.setCoverGapShouldRevert(true);

        (, , , , uint256 nextTs, , , , ,) = sc.circles(id);
        vm.warp(nextTs);
        sc.executeRound(id); // should not revert — alice auto-paused

        assertTrue(sc.positionPaused(id, 0), "alice should be auto-paused");
    }
}
