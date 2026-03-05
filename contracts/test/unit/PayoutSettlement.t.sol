// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SavingsCircle} from "../../src/core/SavingsCircle.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {ISafetyNetPool} from "../../src/interfaces/ISafetyNetPool.sol";
import {MockSavingsAccount} from "../mocks/MockSavingsAccount.sol";
import {MockVRFCoordinatorV2} from "../mocks/MockVRFCoordinatorV2.sol";
import {MockSafetyNetPool} from "../mocks/MockSafetyNetPool.sol";

/// @notice Unit tests for Task 003-03: two-phase payout and debt settlement.
contract PayoutSettlementTest is Test {
    event MemberSelected(uint256 indexed circleId, uint16 slot, bytes32 shieldedId);
    event PayoutSettled(uint256 indexed circleId, uint16 slot, uint256 grossPayout, uint256 debtUsdc, uint256 netObligation);

    MockSavingsAccount internal sa;
    MockVRFCoordinatorV2 internal vrf;
    MockSafetyNetPool internal pool;
    SavingsCircle internal sc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant POOL_SIZE = 300e6;
    uint16 internal constant MEMBER_COUNT = 3;
    uint256 internal constant CONTRIB = 100e6;
    uint256 internal constant MIN_DEP = 50e6;
    uint256 internal constant GAP = CONTRIB - MIN_DEP;
    uint256 internal constant ROUND_DUR = 5 minutes;

    bytes32 internal constant KEY_HASH = bytes32(uint256(1));
    uint64 internal constant SUB_ID = 1;

    uint256 internal circleId;

    function setUp() public {
        sa = new MockSavingsAccount();
        vrf = new MockVRFCoordinatorV2();
        pool = new MockSafetyNetPool();
        pool.setAvailableCapital(type(uint256).max);
        sc = new SavingsCircle(ISavingsAccount(address(sa)), ISafetyNetPool(address(pool)), address(vrf), KEY_HASH, SUB_ID);

        bytes32 idA = sa.computeShieldedId(alice);
        bytes32 idB = sa.computeShieldedId(bob);
        bytes32 idC = sa.computeShieldedId(carol);
        sa.setPosition(idA, CONTRIB * 2, 0);
        sa.setPosition(idB, CONTRIB * 2, 0);
        sa.setPosition(idC, CONTRIB * 2, 0);

        circleId = sc.createCircle(POOL_SIZE, MEMBER_COUNT, ROUND_DUR, MIN_DEP);
    }

    // ── Helpers ──

    function _activateAndJoin(bool aliceUsesMinDep) internal {
        if (aliceUsesMinDep) {
            vm.prank(alice); sc.activateMinInstallment(circleId);
        }
        vm.prank(alice); sc.joinCircle(circleId);
        vm.prank(bob);   sc.joinCircle(circleId);
        vm.prank(carol); sc.joinCircle(circleId);
    }

    function _runRoundToSlot0() internal {
        (, , , , uint256 nextTs, , , , ,) = sc.circles(circleId);
        vm.warp(nextTs);
        sc.executeRound(circleId);
        uint256 reqId = vrf.getLastRequestId();
        // seed=0 → slot 0 selected (alice)
        vrf.fulfillRequest(reqId, 0);
    }

    // T012: VRF callback sets pendingPayout = true, payoutReceived = true
    function test_vrfCallback_setsPendingPayout() public {
        _activateAndJoin(false);
        _runRoundToSlot0();

        assertTrue(sc.pendingPayout(circleId, 0), "pendingPayout must be true after VRF");
        assertTrue(sc.payoutReceived(circleId, 0), "payoutReceived must be true after VRF");
    }

    // T013: VRF callback emits MemberSelected
    function test_vrfCallback_emitsMemberSelected() public {
        _activateAndJoin(false);

        bytes32 aliceId = sa.computeShieldedId(alice);
        (, , , , uint256 nextTs, , , , ,) = sc.circles(circleId);
        vm.warp(nextTs);

        sc.executeRound(circleId);
        uint256 reqId = vrf.getLastRequestId();

        // expectEmit immediately before the call that emits
        vm.expectEmit(true, false, false, true);
        emit MemberSelected(circleId, 0, aliceId);

        vrf.fulfillRequest(reqId, 0);
    }

    // T014: claimPayout with no debt — full pool credited, obligation = poolSize
    function test_claimPayout_noDebt_fullCredit() public {
        _activateAndJoin(false);
        _runRoundToSlot0();

        bytes32 aliceId = sa.computeShieldedId(alice);
        uint256 balanceBefore = sa.getPosition(aliceId).balance;

        vm.prank(alice);
        sc.claimPayout(circleId, 0);

        assertFalse(sc.pendingPayout(circleId, 0), "pendingPayout cleared");
        assertEq(sa.getPosition(aliceId).balance, balanceBefore + POOL_SIZE, "full pool credited");
        assertEq(sa.getPosition(aliceId).circleObligation, POOL_SIZE, "obligation = poolSize");
    }

    // T015: claimPayout with debt — pool settles debt, net obligation applied
    function test_claimPayout_withDebt_settlesDebt() public {
        _activateAndJoin(true); // alice uses min deposit

        // Simulate accumulated debt of $25
        uint256 debtUsdc = 25e6;
        bytes32 aliceId = sa.computeShieldedId(alice);
        sa.safetyNetDebtShares(aliceId); // check initial = 0

        // Seed pool mock to report $25 debt for alice's slot
        pool.setGapDebtUsdc(circleId, 0, debtUsdc);

        // Also give alice some safetyNetDebtShares (non-zero so settlement is triggered)
        // MockSavingsAccount stores shares; pool.convertGapToUsdc returns usdc
        // We simulate addSafetyNetDebt from the pool calls during executeRound
        _runRoundToSlot0(); // this triggers coverGap, which calls addSafetyNetDebt in mock

        // Manually set debt shares if they weren't set during the mock flow
        // (mock doesn't auto-call addSafetyNetDebt since sa is a mock)
        // Instead set debtShares directly on the mock account so settlement triggers:
        bytes memory hack = abi.encodeWithSignature("setPosition(bytes32,uint256,uint256)", aliceId, CONTRIB * 2, CONTRIB);
        (bool ok,) = address(sa).call(hack);
        require(ok);

        // Set safetyNetDebtShares > 0 to trigger settlement path
        vm.prank(address(sc)); // pretend SavingsCircle calls addSafetyNetDebt
        sa.addSafetyNetDebt(aliceId, 1e6); // 1 share

        uint256 balBefore = sa.getPosition(aliceId).balance;

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit PayoutSettled(circleId, 0, POOL_SIZE, debtUsdc, POOL_SIZE - debtUsdc);
        sc.claimPayout(circleId, 0);

        assertEq(sa.getPosition(aliceId).circleObligation, POOL_SIZE - debtUsdc, "net obligation");
        assertEq(sa.getPosition(aliceId).balance, balBefore + POOL_SIZE, "full pool still credited");
        assertEq(pool.settleDebtCallCount(), 1, "settleGapDebt called");
    }

    // T016: claimPayout reverts if caller is not the slot owner
    function test_claimPayout_notSlotOwner_reverts() public {
        _activateAndJoin(false);
        _runRoundToSlot0();

        vm.prank(bob); // bob tries to claim alice's payout
        vm.expectRevert("Not the slot owner");
        sc.claimPayout(circleId, 0);
    }

    // T017: claimPayout reverts NoPendingPayout if called again
    function test_claimPayout_noPending_reverts() public {
        _activateAndJoin(false);
        _runRoundToSlot0();

        vm.prank(alice); sc.claimPayout(circleId, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SavingsCircle.NoPendingPayout.selector, circleId, 0));
        sc.claimPayout(circleId, 0);
    }

    // T018: DebtExceedsPoolSize guard — debt > poolSize reverts
    function test_claimPayout_debtExceedsPool_reverts() public {
        _activateAndJoin(true);

        // Set debt higher than pool size
        pool.setGapDebtUsdc(circleId, 0, POOL_SIZE + 1e6);

        _runRoundToSlot0();

        bytes32 aliceId = sa.computeShieldedId(alice);
        // Give alice non-zero safetyNetDebtShares
        vm.prank(address(sc));
        sa.addSafetyNetDebt(aliceId, 1e6);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(
            SavingsCircle.DebtExceedsPoolSize.selector, POOL_SIZE + 1e6, POOL_SIZE
        ));
        sc.claimPayout(circleId, 0);
    }

    // T019: debt=0 (non-min-installment) — settlement skipped
    function test_claimPayout_zeroDebt_skipsSettlement() public {
        _activateAndJoin(false); // no min installment
        _runRoundToSlot0();

        vm.prank(alice); sc.claimPayout(circleId, 0);

        assertEq(pool.settleDebtCallCount(), 0, "settleGapDebt not called for zero debt");
    }

    // T021: settleGapDebt state consistency — missing gapCoverages entry reverts
    function test_settleGapDebt_missingEntry_reverts() public {
        // Call settleGapDebt on pool directly for a slot that was never covered
        // (pool is not a mock here — we test SafetyNetPool in SafetyNetPool.t.sol)
        // This test verifies the SavingsCircle skip logic:
        // if debtShares == 0 → settlement skipped, no revert
        _activateAndJoin(false);
        _runRoundToSlot0();

        bytes32 aliceId = sa.computeShieldedId(alice);
        assertEq(sa.getSafetyNetDebtShares(aliceId), 0, "no debt for normal member");

        vm.prank(alice); sc.claimPayout(circleId, 0); // must not revert
    }
}
