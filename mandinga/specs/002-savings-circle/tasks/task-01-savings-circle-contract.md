# Task 002-01 — Implement SavingsCircle Contract

**Spec:** 002 — Savings Circle
**Milestone:** 3
**Status:** Done ✓
**Estimated effort:** 16 hours
**Dependencies:** Task 001-02 (SavingsAccount), Chainlink VRF setup
**Parallel-safe:** No

---

## Objective

Implement `SavingsCircle.sol` — the ROSCA mechanic. This contract manages circle formation, member assignment, round execution, Chainlink VRF-driven selection, payout, and circle completion.

---

## Context

The SavingsCircle is the most complex contract in the protocol. Its correctness is critical: a bug here means members don't receive payouts, or receive them in the wrong amount, or the circle fails to complete. Extensive testing is required.

See: Spec 002 all user stories, plan.md §3.2 and §6 (data flow).

---

## Acceptance Criteria

### Contract Structure
- [x] Contract at `contracts/src/core/SavingsCircle.sol`
- [x] Implements `VRFConsumerBaseV2` (Chainlink VRF v2 — v2Plus not yet in installed toolkit; pattern identical for subscription model)
- [x] Constructor takes: `ISavingsAccount savingsAccount`, `ICircleBuffer buffer`, `address vrfCoordinator`, `bytes32 keyHash`, `uint64 subscriptionId`

### Circle Formation
- [x] `createCircle(uint256 poolSize, uint8 memberCount, uint256 roundDuration) returns (uint256 circleId)`:
  - Creates a new circle in `FORMING` status
  - `poolSize` must be evenly divisible by `memberCount`
  - `roundDuration` must be >= 7 days (minimum round length) and <= 365 days (CHK006/CHK007)
  - Returns the new `circleId`
- [x] `joinCircle(uint256 circleId, bytes calldata balanceProof)`:
  - v1: on-chain balance check via `savingsAccount.getWithdrawableBalance(shieldedId)`; ZK proof deferred to v2
  - Assigns member to next available slot; duplicate-join guard via `_isMember` mapping
  - Calls `savingsAccount.setCircleObligation(shieldedId, contributionPerMember)` to lock the contribution amount
  - When all slots filled: transitions circle to `ACTIVE`, sets `nextRoundTimestamp`

### Round Execution
- [x] `executeRound(uint256 circleId)`:
  - Callable by anyone (permissionless) once `block.timestamp >= nextRoundTimestamp`
  - Checks no pending VRF request for this circle (prevents double execution)
  - Requests randomness from Chainlink VRF
  - Updates `nextRoundTimestamp` for the next round
- [x] `fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)` (VRF callback):
  - Identifies the circle associated with `requestId`
  - Builds array of eligible members (not paused, not already received payout)
  - Derives selected slot from `randomWords[0] % eligibleCount`
  - Emits `RoundSkipped` if no eligible members remain (CHK028)
  - Calls `_processPayout(circleId, selectedSlot)`
- [x] `_processPayout(uint256 circleId, uint8 slot)` (internal):
  - Calls `savingsAccount.setCircleObligation(memberId, poolSize)` — raises obligation to full pool
  - Credits `poolSize` to selected member's balance via `savingsAccount.creditPrincipal()` (dedicated principal-crediting function added to ISavingsAccount — CHK027 atomicity)
  - Marks `payoutReceived[slot] = true`
  - Increments `roundsCompleted`
  - Emits `RoundExecuted(circleId, roundNumber)` (no member identity in event)
  - If `roundsCompleted == totalRounds`: calls `_completeCircle(circleId)`

### Circle Completion
- [x] `_completeCircle(uint256 circleId)` (internal):
  - For each member: calls `savingsAccount.setCircleObligation(memberId, 0)` — releases all obligations
  - Sets circle status to `COMPLETED`
  - Emits `CircleCompleted(circleId)`

### Pause Handling
- [x] `checkAndPause(uint256 circleId, uint8 slot)` — callable by anyone:
  - Checks if member at `slot` has balance below their obligation
  - If balance >= obligation: no-op (no-emit)
  - If yes: sets `positionPaused[slot] = true`, instructs `CircleBuffer.coverSlot()`, emits `MemberPaused`
- [x] `resumePausedMember(uint256 circleId, uint8 slot, bytes calldata balanceProof)`:
  - v1: on-chain check that withdrawable balance >= contributionPerMember; ZK proof deferred to v2
  - Sets `positionPaused[slot] = false`, calls `CircleBuffer.releaseSlot()`, emits `MemberResumed`

### Tests
- [x] Unit tests at `test/unit/SavingsCircle.t.sol` (28 tests, all passing):
  - Create circle → join N members → all slots filled → circle goes ACTIVE ✓
  - `executeRound` before `nextRoundTimestamp` → reverts ✓
  - `executeRound` after timestamp → VRF request emitted ✓
  - VRF callback → correct member selected → payout processed → obligation updated ✓
  - Selected member cannot be selected again in same cycle ✓
  - Paused member excluded from selection ✓
  - After all rounds: all obligations released, circle COMPLETED ✓
  - `checkAndPause` with sufficient balance → no-op ✓
  - `checkAndPause` with insufficient balance → member paused ✓
  - CHK006–CHK009 guard tests (invalid params revert) ✓
  - CHK028: all-paused → RoundSkipped ✓

- [x] Integration test at `test/integration/FullCircleLifecycle.t.sol` (3 tests, all passing):
  - 10 members, 10 rounds, all execute in sequence ✓
  - After full cycle: verify each member received payout exactly once ✓
  - CHK015: zero-yield scenario — circle completes normally ✓
  - Verify all obligations = 0 at completion ✓

---

## Output Files

- `contracts/src/core/SavingsCircle.sol`
- `test/unit/SavingsCircle.test.ts`
- `test/integration/full_circle_lifecycle.test.ts`

---

## Notes

- Use Chainlink VRF v2+ (subscription model) — not v1 or v2
- The VRF request must store the `circleId` so the callback can route correctly: `mapping(uint256 requestId => uint256 circleId) private vrfRequests`
- In the balance proof check for `joinCircle`, use a mock verifier in tests and wire the real `BalanceVerifier` in production deployments
- The `_processPayout` function's balance crediting should be done through `SavingsAccount.creditYield` for now, but note that this is semantically a principal increase, not yield. Consider a separate `creditPrincipal` function on the interface to be clearer about the distinction.
- Test the reentrancy path: a malicious `SavingsAccount` implementation should not be able to reenter `SavingsCircle` during a payout callback
