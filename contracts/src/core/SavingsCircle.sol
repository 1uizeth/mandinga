// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {ISavingsAccount} from "../interfaces/ISavingsAccount.sol";
import {ICircleBuffer} from "../interfaces/ICircleBuffer.sol";

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
    ICircleBuffer public immutable buffer;

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
    }

    uint256 public nextCircleId;

    mapping(uint256 circleId => Circle) public circles;
    mapping(uint256 circleId => bytes32[]) internal _members;
    mapping(uint256 circleId => mapping(uint16 slot => bool)) public payoutReceived;
    mapping(uint256 circleId => mapping(uint16 slot => bool)) public positionPaused;

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
    /// @notice Emitted when VRF callback finds no eligible member (all paused). (CHK028)
    event RoundSkipped(uint256 indexed circleId, uint16 roundNumber);
    event CircleCompleted(uint256 indexed circleId);
    event MemberPaused(uint256 indexed circleId, uint16 slot);
    event MemberResumed(uint256 indexed circleId, uint16 slot);

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    error InvalidPoolSize();
    error InvalidMemberCount(uint16 given, uint16 min, uint16 max);
    error InvalidRoundDuration(uint256 given, uint256 min, uint256 max);
    error PoolSizeNotDivisible(uint256 poolSize, uint16 memberCount);
    error CircleNotForming(uint256 circleId);
    error CircleNotActive(uint256 circleId);
    error CircleFull(uint256 circleId);
    error AlreadyMember(uint256 circleId, bytes32 shieldedId);
    error InsufficientBalance(uint256 available, uint256 required);
    error RoundNotDue(uint256 nextTimestamp, uint256 current);
    error VrfRequestPending(uint256 circleId, uint256 requestId);
    error SlotOutOfRange(uint16 slot, uint16 memberCount);
    error MemberNotPaused(uint256 circleId, uint16 slot);
    error MemberAlreadyPaused(uint256 circleId, uint16 slot);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(
        ISavingsAccount _savingsAccount,
        ICircleBuffer _buffer,
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(vrfCoordinator) {
        savingsAccount = _savingsAccount;
        buffer = _buffer;
        _coordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    // ──────────────────────────────────────────────
    // Circle formation
    // ──────────────────────────────────────────────

    /// @notice Create a new circle in FORMING state.
    /// @param poolSize     Total USDC distributed per round (6 decimals)
    /// @param memberCount  Number of members / rounds (2–50)
    /// @param roundDuration Seconds per round (>= 1 minute)
    /// @return circleId    The new circle's identifier
    function createCircle(
        uint256 poolSize,
        uint16 memberCount,
        uint256 roundDuration
    ) external nonReentrant returns (uint256 circleId) {
        if (poolSize == 0) revert InvalidPoolSize();
        if (memberCount < MIN_MEMBERS || memberCount > MAX_MEMBERS) {
            revert InvalidMemberCount(memberCount, MIN_MEMBERS, MAX_MEMBERS);
        }
        if (roundDuration < MIN_ROUND_DURATION) {
            revert InvalidRoundDuration(roundDuration, MIN_ROUND_DURATION, MAX_ROUND_DURATION);
        }
        if (poolSize % memberCount != 0) revert PoolSizeNotDivisible(poolSize, memberCount);

        circleId = nextCircleId++;
        uint256 contributionPerMember = poolSize / memberCount;

        circles[circleId] = Circle({
            poolSize: poolSize,
            memberCount: memberCount,
            contributionPerMember: contributionPerMember,
            roundDuration: roundDuration,
            nextRoundTimestamp: 0,
            filledSlots: 0,
            roundsCompleted: 0,
            pendingVrfRequestId: 0,
            status: CircleStatus.FORMING
        });

        _members[circleId] = new bytes32[](memberCount);

        emit CircleCreated(circleId, poolSize, memberCount, roundDuration);
    }

    /// @notice Join a circle in FORMING state.
    /// @param circleId    Target circle
    /// @param balanceProof v1: unused (on-chain balance check performed instead).
    function joinCircle(uint256 circleId, bytes calldata balanceProof) external nonReentrant {
        balanceProof;

        Circle storage circle = circles[circleId];
        if (circle.status != CircleStatus.FORMING) revert CircleNotForming(circleId);
        if (circle.filledSlots >= circle.memberCount) revert CircleFull(circleId);

        bytes32 shieldedId = savingsAccount.computeShieldedId(msg.sender);
        if (_isMember[circleId][shieldedId]) revert AlreadyMember(circleId, shieldedId);

        uint256 available = savingsAccount.getWithdrawableBalance(shieldedId);
        if (available < circle.contributionPerMember) {
            revert InsufficientBalance(available, circle.contributionPerMember);
        }

        uint16 slot = circle.filledSlots;
        _members[circleId][slot] = shieldedId;
        _isMember[circleId][shieldedId] = true;
        circle.filledSlots++;

        // Lock contribution in SavingsAccount
        savingsAccount.setCircleObligation(shieldedId, circle.contributionPerMember);

        emit MemberJoined(circleId, slot, shieldedId);

        // All slots filled → activate circle
        if (circle.filledSlots == circle.memberCount) {
            circle.status = CircleStatus.ACTIVE;
            circle.nextRoundTimestamp = block.timestamp + circle.roundDuration;
            emit CircleActivated(circleId, circle.nextRoundTimestamp);
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
        _processPayout(circleId, selectedSlot);
    }

    // ──────────────────────────────────────────────
    // Internal payout logic
    // ──────────────────────────────────────────────

    function _processPayout(uint256 circleId, uint16 slot) internal {
        Circle storage circle = circles[circleId];
        bytes32 memberId = _members[circleId][slot];

        // 1. Raise obligation to full poolSize — member committed for remaining rounds
        savingsAccount.setCircleObligation(memberId, circle.poolSize);

        // 2. Credit the lump-sum payout to the winner's balance
        savingsAccount.creditPrincipal(memberId, circle.poolSize);

        // 3. Mark slot as paid
        payoutReceived[circleId][slot] = true;
        circle.roundsCompleted++;

        emit RoundExecuted(circleId, circle.roundsCompleted);

        if (circle.roundsCompleted == circle.memberCount) {
            _completeCircle(circleId);
        }
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
    /// @dev Instructs CircleBuffer to cover the slot for the grace period.
    function checkAndPause(uint256 circleId, uint16 slot) external nonReentrant {
        Circle storage circle = circles[circleId];
        if (circle.status != CircleStatus.ACTIVE) revert CircleNotActive(circleId);
        if (slot >= circle.memberCount) revert SlotOutOfRange(slot, circle.memberCount);
        if (positionPaused[circleId][slot]) revert MemberAlreadyPaused(circleId, slot);

        bytes32 memberId = _members[circleId][slot];
        ISavingsAccount.Position memory pos = savingsAccount.getPosition(memberId);

        // Sufficient balance — no action needed
        if (pos.balance >= pos.circleObligation) return;

        positionPaused[circleId][slot] = true;
        buffer.coverSlot(circleId, slot, circle.contributionPerMember);
        emit MemberPaused(circleId, slot);
    }

    /// @notice Allow a paused member to resume once their balance is restored.
    /// @param balanceProof v1: unused; v2: ZK proof that balance >= contributionPerMember.
    function resumePausedMember(
        uint256 circleId,
        uint16 slot,
        bytes calldata balanceProof
    ) external nonReentrant {
        balanceProof;

        Circle storage circle = circles[circleId];
        if (circle.status != CircleStatus.ACTIVE) revert CircleNotActive(circleId);
        if (slot >= circle.memberCount) revert SlotOutOfRange(slot, circle.memberCount);
        if (!positionPaused[circleId][slot]) revert MemberNotPaused(circleId, slot);

        bytes32 memberId = _members[circleId][slot];
        uint256 available = savingsAccount.getWithdrawableBalance(memberId);
        if (available < circle.contributionPerMember) {
            revert InsufficientBalance(available, circle.contributionPerMember);
        }

        positionPaused[circleId][slot] = false;
        buffer.releaseSlot(circleId, slot);
        emit MemberResumed(circleId, slot);
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
