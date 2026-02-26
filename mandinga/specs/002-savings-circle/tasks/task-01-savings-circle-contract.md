# Task 002-01 — Implement SavingsCircle Contract

**Spec:** 002 — Savings Circle
**Milestone:** 3
**Status:** Blocked on Milestone 2 (SavingsAccount complete and deployed to testnet)
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
- [ ] Contract at `contracts/core/SavingsCircle.sol`
- [ ] Implements `VRFConsumerBaseV2Plus` (Chainlink VRF v2+)
- [ ] Constructor takes: `ISavingsAccount savingsAccount`, `ICircleBuffer buffer`, `address vrfCoordinator`, `bytes32 keyHash`, `uint256 subscriptionId`

### Circle Formation
- [ ] `createCircle(uint256 poolSize, uint8 memberCount, uint256 roundDuration) returns (uint256 circleId)`:
  - Creates a new circle in `FORMING` status
  - `poolSize` must be evenly divisible by `memberCount`
  - `roundDuration` must be >= 7 days (minimum round length)
  - Returns the new `circleId`
- [ ] `joinCircle(uint256 circleId, bytes calldata balanceProof)`:
  - Verifies `balanceProof` (ZK proof that caller's balance >= `contributionPerMember`)
  - Assigns member to next available slot
  - Calls `savingsAccount.setCircleObligation(shieldedId, contributionPerMember)` to lock the contribution amount
  - When all slots filled: transitions circle to `ACTIVE`, sets `nextRoundTimestamp`

### Round Execution
- [ ] `executeRound(uint256 circleId)`:
  - Callable by anyone (permissionless) once `block.timestamp >= nextRoundTimestamp`
  - Checks no pending VRF request for this circle (prevents double execution)
  - Requests randomness from Chainlink VRF
  - Updates `nextRoundTimestamp` for the next round
- [ ] `fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)` (VRF callback):
  - Identifies the circle associated with `requestId`
  - Builds array of eligible members (not paused, not already received payout)
  - Derives selected slot from `randomWords[0] % eligibleCount`
  - Calls `_processPayout(circleId, selectedSlot)`
- [ ] `_processPayout(uint256 circleId, uint8 slot)` (internal):
  - Calls `savingsAccount.setCircleObligation(memberId, poolSize)` — raises obligation to full pool
  - Credits `poolSize` to selected member's balance via `savingsAccount.creditYield()` (semantically, it's a balance increase, not yield, but uses the same crediting mechanism)
  - Marks `payoutReceived[slot] = true`
  - Increments `roundsCompleted`
  - Emits `RoundExecuted(circleId, roundNumber)` (no member identity in event)
  - If `roundsCompleted == totalRounds`: calls `_completeCircle(circleId)`

### Circle Completion
- [ ] `_completeCircle(uint256 circleId)` (internal):
  - For each member: calls `savingsAccount.setCircleObligation(memberId, 0)` — releases all obligations
  - Sets circle status to `COMPLETED`
  - Emits `CircleCompleted(circleId)`

### Pause Handling
- [ ] `checkAndPause(uint256 circleId, uint8 slot)` — callable by anyone:
  - Checks if member at `slot` has balance below their obligation
  - If yes: sets `positionPaused[slot] = true`
  - Instructs `CircleBuffer` to cover this slot's contribution for the grace period
  - Emits `MemberPaused(circleId, slot)`
- [ ] `resumePausedMember(uint256 circleId, uint8 slot, bytes calldata balanceProof)`:
  - Verifies balance proof shows balance >= obligation
  - Sets `positionPaused[slot] = false`
  - Emits `MemberResumed(circleId, slot)`

### Tests
- [ ] Unit tests at `test/unit/SavingsCircle.test.ts`:
  - Create circle → join 10 members → all slots filled → circle goes ACTIVE
  - `executeRound` before `nextRoundTimestamp` → reverts
  - `executeRound` after timestamp → VRF request emitted
  - VRF callback → correct member selected → payout processed → obligation updated
  - Selected member cannot be selected again in same cycle
  - Paused member excluded from selection
  - After all rounds: all obligations released, circle COMPLETED
  - `checkAndPause` with sufficient balance → no-op
  - `checkAndPause` with insufficient balance → member paused

- [ ] Integration test at `test/integration/full_circle_lifecycle.test.ts`:
  - 10 members, 10 rounds, all execute in sequence
  - After full cycle: verify each member received payout exactly once
  - Verify total yield accrued equals expected (using mock yield router)
  - Verify all obligations = 0 at completion

---

## Output Files

- `contracts/core/SavingsCircle.sol`
- `test/unit/SavingsCircle.test.ts`
- `test/integration/full_circle_lifecycle.test.ts`

---

## Notes

- Use Chainlink VRF v2+ (subscription model) — not v1 or v2
- The VRF request must store the `circleId` so the callback can route correctly: `mapping(uint256 requestId => uint256 circleId) private vrfRequests`
- In the balance proof check for `joinCircle`, use a mock verifier in tests and wire the real `BalanceVerifier` in production deployments
- The `_processPayout` function's balance crediting should be done through `SavingsAccount.creditYield` for now, but note that this is semantically a principal increase, not yield. Consider a separate `creditPrincipal` function on the interface to be clearer about the distinction.
- Test the reentrancy path: a malicious `SavingsAccount` implementation should not be able to reenter `SavingsCircle` during a payout callback
