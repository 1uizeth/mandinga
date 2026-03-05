// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {ISavingsAccount} from "../interfaces/ISavingsAccount.sol";
import {ICircleBuffer} from "../interfaces/ICircleBuffer.sol";
import {ISafetyNetPool} from "../interfaces/ISafetyNetPool.sol";

/// @title SavingsCircle
/// @notice ROSCA mechanic — manages circle formation, VRF-driven round execution,
///         payout distribution, and circle completion.
///
/// @dev Design summary
///  • Members deposit into their own SavingsAccount before joining.
///  • Joining locks `contributionPerMember` as a circle obligation.
///  • Each round: a permissionless call requests Chainlink VRF randomness.
///  • The VRF callback selects one eligible (not paused, not yet paid) member.
///  • The selected member's obligation is raised to `poolSize` and their balance
///    is credited with `poolSize` — they hold the virtual lump sum, locked until
///    the circle completes and all obligations are released.
///  • After every member has been selected once, the circle completes and all
///    obligations are reset to zero.
///
contract SavingsCircle is VRFConsumerBaseV2, ReentrancyGuard {
    /// @notice Minimum duration of a single round.
    /// @dev Relaxed to 1 minute for testnet convenience. Restore to 7 days for mainnet.
    uint256 public constant MIN_ROUND_DURATION = 1 minutes;

    /// @notice Maximum duration of a single round.
    uint256 public constant MAX_ROUND_DURATION = type(uint256).max;

    /// @notice Minimum number of members per circle.
    uint16 public constant MIN_MEMBERS = 2;

    /// @notice Maximum number of members per circle.
    uint16 public constant MAX_MEMBERS = 1_000;

    /// @notice Minimum allowed minDepositPerRound (1 USDC in 6-decimal). Mirrors SafetyNetPool.
    uint256 public constant MIN_MIN_DEPOSIT = 1e6;


    // ──────────────────────────────────────────────
    // VRF configuration
    // ──────────────────────────────────────────────

    VRFCoordinatorV2Interface private immutable _coordinator;
    bytes32 public immutable keyHash;
    uint64 public immutable subscriptionId;

    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant CALLBACK_GAS_LIMIT = 300_000;
    uint32 private constant NUM_WORDS = 1;

    // ──────────────────────────────────────────────
    // Protocol contracts
    // ──────────────────────────────────────────────

    ISavingsAccount public immutable savingsAccount;
    /// @notice Safety Net Pool — implements ISafetyNetPool which extends ICircleBuffer.
    ISafetyNetPool public immutable pool;

    // ──────────────────────────────────────────────
    // Circle data structures
    // ──────────────────────────────────────────────

    enum CircleStatus { FORMING, ACTIVE, COMPLETED }

    struct Circle {
        uint256 poolSize;
        uint16 memberCount;
        uint256 contributionPerMember;
        uint256 roundDuration;
        uint256 nextRoundTimestamp;
        uint16 filledSlots;
        uint16 roundsCompleted;
        uint256 pendingVrfRequestId;   // 0 = no pending request
        CircleStatus status;
        /// @notice Minimum installment per round (0 = feature disabled). Pool covers the gap.
        uint256 minDepositPerRound;
    }

    uint256 public nextCircleId;

    mapping(uint256 circleId => Circle) public circles;
    mapping(uint256 circleId => bytes32[]) internal _members;
    mapping(uint256 circleId => mapping(uint16 slot => bool)) public payoutReceived;
    mapping(uint256 circleId => mapping(uint16 slot => bool)) public positionPaused;

    /// @notice True if a member opted in to minimum-installment coverage.
    mapping(uint256 circleId => mapping(bytes32 shieldedId => bool)) public usesMinInstallment;

    /// @notice True for a slot when VRF has selected the member but claimPayout not yet called.
    mapping(uint256 circleId => mapping(uint16 slot => bool)) public pendingPayout;

    /// @dev Duplicate-join guard: circleId → shieldedId → already joined
    mapping(uint256 circleId => mapping(bytes32 shieldedId => bool)) internal _isMember;

    /// @dev VRF request routing: requestId → circleId
    mapping(uint256 requestId => uint256 circleId) public vrfRequests;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event CircleCreated(uint256 indexed circleId, uint256 poolSize, uint16 memberCount, uint256 roundDuration);
    event MemberJoined(uint256 indexed circleId, uint16 slot, bytes32 shieldedId);
    event CircleActivated(uint256 indexed circleId, uint256 firstRoundTimestamp);
    event RoundRequested(uint256 indexed circleId, uint256 vrfRequestId);
    event RoundExecuted(uint256 indexed circleId, uint16 roundNumber);
    /// @notice Emitted when VRF callback finds no eligible member (all paused).
    event RoundSkipped(uint256 indexed circleId, uint16 roundNumber);
    event CircleCompleted(uint256 indexed circleId);
    event MemberPaused(uint256 indexed circleId, uint16 slot);
    event MemberResumed(uint256 indexed circleId, uint16 slot);
    /// @notice Phase 1 of two-phase payout: VRF marks winner.
    event MemberSelected(uint256 indexed circleId, uint16 slot, bytes32 shieldedId);
    /// @notice Phase 2 of two-phase payout: settlement complete.
    event PayoutSettled(uint256 indexed circleId, uint16 slot, uint256 grossPayout, uint256 debtUsdc, uint256 netObligation);
    /// @notice Emitted when a member activates minimum-installment coverage.
    event MinInstallmentActivated(uint256 indexed circleId, bytes32 shieldedId);

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    error InvalidPoolSize();
    error InvalidMemberCount(uint16 given, uint16 min, uint16 max);
    error InvalidRoundDuration(uint256 given, uint256 min, uint256 max);
    error PoolSizeNotDivisible(uint256 poolSize, uint16 memberCount);
    error CircleNotForming(uint256 circleId);
    error CircleNotActive(uint256 circleId);
    error CircleAlreadyActive(uint256 circleId);
    error CircleFull(uint256 circleId);
    error AlreadyMember(uint256 circleId, bytes32 shieldedId);
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientPoolDepth(uint256 available, uint256 required);
    error InvalidMinDeposit(uint256 minDeposit, uint256 contribution);
    error MinDepositTooLow(uint256 minDeposit, uint256 minimum);
    error RoundNotDue(uint256 nextTimestamp, uint256 current);
    error VrfRequestPending(uint256 circleId, uint256 requestId);
    error SlotOutOfRange(uint16 slot, uint16 memberCount);
    error MemberNotPaused(uint256 circleId, uint16 slot);
    error MemberAlreadyPaused(uint256 circleId, uint16 slot);
    error NoPendingPayout(uint256 circleId, uint16 slot);
    error DebtExceedsPoolSize(uint256 debtUsdc, uint256 poolSize);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(
        ISavingsAccount _savingsAccount,
        ISafetyNetPool _pool,
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(vrfCoordinator) {
        savingsAccount = _savingsAccount;
        pool = _pool;
        _coordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    // ──────────────────────────────────────────────
    // Circle formation
    // ──────────────────────────────────────────────

    /// @notice Create a new circle in FORMING state.
    /// @param poolSize           Total USDC distributed per round (6 decimals)
    /// @param memberCount        Number of members / rounds (2–1000)
    /// @param roundDuration      Seconds per round (>= 1 minute)
    /// @param minDepositPerRound Minimum installment per round (0 = disabled; pool covers gap)
    /// @return circleId          The new circle's identifier
    function createCircle(
        uint256 poolSize,
        uint16 memberCount,
        uint256 roundDuration,
        uint256 minDepositPerRound
    ) external nonReentrant returns (uint256 circleId) {
        if (poolSize == 0) revert InvalidPoolSize();
        if (memberCount < MIN_MEMBERS || memberCount > MAX_MEMBERS) {
            revert InvalidMemberCount(memberCount, MIN_MEMBERS, MAX_MEMBERS);
        }
        if (roundDuration < MIN_ROUND_DURATION) {
            revert InvalidRoundDuration(roundDuration, MIN_ROUND_DURATION, MAX_ROUND_DURATION);
        }
        if (poolSize % memberCount != 0) revert PoolSizeNotDivisible(poolSize, memberCount);

        uint256 contributionPerMember = poolSize / memberCount;

        if (minDepositPerRound != 0) {
            if (minDepositPerRound < MIN_MIN_DEPOSIT) {
                revert MinDepositTooLow(minDepositPerRound, MIN_MIN_DEPOSIT);
            }
            if (minDepositPerRound >= contributionPerMember) {
                revert InvalidMinDeposit(minDepositPerRound, contributionPerMember);
            }
        }

        circleId = nextCircleId++;

        circles[circleId] = Circle({
            poolSize: poolSize,
            memberCount: memberCount,
            contributionPerMember: contributionPerMember,
            roundDuration: roundDuration,
            nextRoundTimestamp: 0,
            filledSlots: 0,
            roundsCompleted: 0,
            pendingVrfRequestId: 0,
            status: CircleStatus.FORMING,
            minDepositPerRound: minDepositPerRound
        });

        _members[circleId] = new bytes32[](memberCount);

        emit CircleCreated(circleId, poolSize, memberCount, roundDuration);
    }

    /// @notice Opt in to minimum-installment coverage for a circle you are about to join.
    /// @dev Must be called BEFORE joinCircle while circle is still in FORMING state.
    function activateMinInstallment(uint256 circleId) external {
        Circle storage c = circles[circleId];
        if (c.status != CircleStatus.FORMING) revert CircleAlreadyActive(circleId);
        if (c.minDepositPerRound == 0) revert InvalidMinDeposit(0, c.contributionPerMember);

        bytes32 shieldedId = savingsAccount.computeShieldedId(msg.sender);
        usesMinInstallment[circleId][shieldedId] = true;
        emit MinInstallmentActivated(circleId, shieldedId);
    }

    /// @notice Join a circle in FORMING state.
    /// @param circleId Target circle
    function joinCircle(uint256 circleId) external nonReentrant {

        Circle storage c = circles[circleId];
        if (c.status != CircleStatus.FORMING) revert CircleNotForming(circleId);
        if (c.filledSlots >= c.memberCount) revert CircleFull(circleId);

        bytes32 shieldedId = savingsAccount.computeShieldedId(msg.sender);
        if (_isMember[circleId][shieldedId]) revert AlreadyMember(circleId, shieldedId);

        uint256 available = savingsAccount.getWithdrawableBalance(shieldedId);
        if (available < c.contributionPerMember) {
            revert InsufficientBalance(available, c.contributionPerMember);
        }

        // Pool depth pre-check for min-installment members (AC-006-1)
        if (usesMinInstallment[circleId][shieldedId] && c.minDepositPerRound > 0) {
            uint256 gap = c.contributionPerMember - c.minDepositPerRound;
            uint256 nAlreadyJoined = _countMinInstallmentMembers(circleId, c.filledSlots);
            uint256 required = (nAlreadyJoined + 1) * gap * c.memberCount;
            uint256 poolAvailable = pool.getAvailableCapital();
            if (poolAvailable < required) revert InsufficientPoolDepth(poolAvailable, required);
        }

        uint16 slot = c.filledSlots;
        _members[circleId][slot] = shieldedId;
        _isMember[circleId][shieldedId] = true;
        c.filledSlots++;

        // Lock contribution in SavingsAccount
        savingsAccount.setCircleObligation(shieldedId, c.contributionPerMember);

        emit MemberJoined(circleId, slot, shieldedId);

        // All slots filled → activate circle
        if (c.filledSlots == c.memberCount) {
            c.status = CircleStatus.ACTIVE;
            c.nextRoundTimestamp = block.timestamp + c.roundDuration;
            emit CircleActivated(circleId, c.nextRoundTimestamp);
        }
    }

    /// @dev Count min-installment members already joined (for pool depth check).
    function _countMinInstallmentMembers(uint256 circleId, uint16 filledSlots) internal view returns (uint256 count) {
        for (uint16 i = 0; i < filledSlots; i++) {
            if (usesMinInstallment[circleId][_members[circleId][i]]) count++;
        }
    }

    // ──────────────────────────────────────────────
    // Round execution
    // ──────────────────────────────────────────────

    /// @notice Permissionless entry point to trigger a round. Requests VRF randomness.
    /// @param circleId Target circle
    function executeRound(uint256 circleId) external nonReentrant {
        Circle storage circle = circles[circleId];
        if (circle.status != CircleStatus.ACTIVE) revert CircleNotActive(circleId);
        if (block.timestamp < circle.nextRoundTimestamp) {
            revert RoundNotDue(circle.nextRoundTimestamp, block.timestamp);
        }
        if (circle.pendingVrfRequestId != 0) {
            revert VrfRequestPending(circleId, circle.pendingVrfRequestId);
        }

        // Cover gaps for active min-installment members (must run before VRF request)
        if (circle.minDepositPerRound > 0) {
            uint256 gap = circle.contributionPerMember - circle.minDepositPerRound;
            uint16 mc = circle.memberCount;
            for (uint16 s = 0; s < mc; s++) {
                bytes32 mid = _members[circleId][s];
                if (!usesMinInstallment[circleId][mid]) continue;
                if (payoutReceived[circleId][s]) continue;
                if (positionPaused[circleId][s]) continue;
                try pool.coverGap(circleId, s, mid, gap) {} catch {
                    // Pool insufficient — auto-pause this member
                    _pauseSlot(circleId, s);
                }
            }
        }

        uint256 requestId = _coordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        vrfRequests[requestId] = circleId;
        circle.pendingVrfRequestId = requestId;

        // Advance timestamp immediately to prevent back-to-back executeRound spam
        circle.nextRoundTimestamp = block.timestamp + circle.roundDuration;

        emit RoundRequested(circleId, requestId);
    }

    /// @notice Chainlink VRF callback. Selects a member and processes payout.
    /// @dev Cannot revert — emits RoundSkipped if no eligible member exists. (CHK028)
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 circleId = vrfRequests[requestId];
        Circle storage circle = circles[circleId];

        circle.pendingVrfRequestId = 0;

        // Build eligible member set: not paused AND not already received payout
        uint16 memberCount = circle.memberCount;
        uint16[] memory eligible = new uint16[](memberCount);
        uint16 eligibleCount = 0;

        for (uint16 i = 0; i < memberCount; i++) {
            if (!positionPaused[circleId][i] && !payoutReceived[circleId][i]) {
                eligible[eligibleCount] = i;
                eligibleCount++;
            }
        }

        if (eligibleCount == 0) {
            emit RoundSkipped(circleId, circle.roundsCompleted);
            return;
        }

        uint16 selectedSlot = eligible[randomWords[0] % eligibleCount];
        _markPayout(circleId, selectedSlot);
    }

    // ──────────────────────────────────────────────
    // Two-phase payout logic (Task 003-03)
    // ──────────────────────────────────────────────

    /// @dev Phase 1 — called from VRF callback. Lightweight: only sets flags, no external
    ///      settlement calls. MUST NOT revert (VRF callback invariant).
    function _markPayout(uint256 circleId, uint16 slot) internal {
        pendingPayout[circleId][slot] = true;
        payoutReceived[circleId][slot] = true;
        circles[circleId].roundsCompleted++;

        emit MemberSelected(circleId, slot, _members[circleId][slot]);
        emit RoundExecuted(circleId, circles[circleId].roundsCompleted);

        if (circles[circleId].roundsCompleted == circles[circleId].memberCount) {
            _completeCircle(circleId);
        }
    }

    /// @notice Phase 2 — settle debt and credit payout. Permissionless (like executeRound).
    /// @param circleId Target circle
    /// @param slot     Slot of the selected member (caller must be the member at this slot)
    function claimPayout(uint256 circleId, uint16 slot) external nonReentrant {
        if (!pendingPayout[circleId][slot]) revert NoPendingPayout(circleId, slot);

        bytes32 memberId = _members[circleId][slot];
        // Verify caller is the member at this slot
        bytes32 callerShieldedId = savingsAccount.computeShieldedId(msg.sender);
        require(callerShieldedId == memberId, "Not the slot owner");

        Circle storage c = circles[circleId];
        uint256 poolSize = c.poolSize;

        uint256 debtUsdc = 0;

        // Settle gap debt if the member has any
        uint256 debtShares = savingsAccount.getSafetyNetDebtShares(memberId);
        if (debtShares > 0) {
            debtUsdc = pool.convertGapToUsdc(circleId, slot);
            // Safety guard — solvency guarantee makes this unreachable in normal operation
            if (debtUsdc > poolSize) revert DebtExceedsPoolSize(debtUsdc, poolSize);
            pool.settleGapDebt(circleId, slot);
            savingsAccount.clearSafetyNetDebt(memberId);
        }

        uint256 netObligation = poolSize - debtUsdc;

        savingsAccount.setCircleObligation(memberId, netObligation);
        savingsAccount.creditPrincipal(memberId, poolSize);

        pendingPayout[circleId][slot] = false;

        emit PayoutSettled(circleId, slot, poolSize, debtUsdc, netObligation);
    }

    function _completeCircle(uint256 circleId) internal {
        Circle storage circle = circles[circleId];
        uint16 memberCount = circle.memberCount;

        // Release all obligations so every member can withdraw freely
        for (uint16 i = 0; i < memberCount; i++) {
            bytes32 memberId = _members[circleId][i];
            savingsAccount.setCircleObligation(memberId, 0);
        }

        circle.status = CircleStatus.COMPLETED;
        emit CircleCompleted(circleId);
    }

    // ──────────────────────────────────────────────
    // Pause / resume
    // ──────────────────────────────────────────────

    /// @notice Permissionless check: pauses a member whose balance fell below obligation.
    function checkAndPause(uint256 circleId, uint16 slot) external nonReentrant {
        Circle storage c = circles[circleId];
        if (c.status != CircleStatus.ACTIVE) revert CircleNotActive(circleId);
        if (slot >= c.memberCount) revert SlotOutOfRange(slot, c.memberCount);
        if (positionPaused[circleId][slot]) revert MemberAlreadyPaused(circleId, slot);

        bytes32 memberId = _members[circleId][slot];
        ISavingsAccount.Position memory pos = savingsAccount.getPosition(memberId);

        // Sufficient balance — no action needed
        if (pos.balance >= pos.circleObligation) return;

        _pauseSlot(circleId, slot);
    }

    /// @notice Allow a paused member to resume once their balance is restored.
    function resumePausedMember(uint256 circleId, uint16 slot) external nonReentrant {

        Circle storage c = circles[circleId];
        if (c.status != CircleStatus.ACTIVE) revert CircleNotActive(circleId);
        if (slot >= c.memberCount) revert SlotOutOfRange(slot, c.memberCount);
        if (!positionPaused[circleId][slot]) revert MemberNotPaused(circleId, slot);

        bytes32 memberId = _members[circleId][slot];
        uint256 available = savingsAccount.getWithdrawableBalance(memberId);
        if (available < c.contributionPerMember) {
            revert InsufficientBalance(available, c.contributionPerMember);
        }

        positionPaused[circleId][slot] = false;
        pool.releaseSlot(circleId, slot);
        emit MemberResumed(circleId, slot);
    }

    /// @dev Internal pause: sets flag and instructs pool to cover the slot.
    function _pauseSlot(uint256 circleId, uint16 slot) internal {
        positionPaused[circleId][slot] = true;
        pool.coverSlot(circleId, slot, circles[circleId].contributionPerMember);
        emit MemberPaused(circleId, slot);
    }

    // ──────────────────────────────────────────────
    // View helpers
    // ──────────────────────────────────────────────

    /// @notice Return the shieldedId of a member at a given slot.
    function getMember(uint256 circleId, uint16 slot) external view returns (bytes32) {
        return _members[circleId][slot];
    }

    /// @notice Return all member shieldedIds for a circle.
    function getMembers(uint256 circleId) external view returns (bytes32[] memory) {
        return _members[circleId];
    }

    /// @notice Count eligible members (not paused, not yet paid) for the next VRF selection.
    function getEligibleCount(uint256 circleId) external view returns (uint16 count) {
        Circle storage circle = circles[circleId];
        for (uint16 i = 0; i < circle.memberCount; i++) {
            if (!positionPaused[circleId][i] && !payoutReceived[circleId][i]) {
                count++;
            }
        }
    }
}
