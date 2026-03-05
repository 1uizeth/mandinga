# Task 003-05 — Reallocation Support (US-005)

**Spec:** 003 — Safety Net Pool (v1.0) — US-005
**Milestone:** 6 (deferred from Milestone 5)
**Status:** Deferred — blocked by Spec 002 US-008
**Estimated effort:** 12 hours (estimate — pending US-008 design)
**Dependencies:**
  - Task 003-02 (minDepositPerRound + coverGap)
  - Task 003-03 (claimPayout + settleGapDebt)
  - **Spec 002 US-008** (member reallocation out of a circle) — **NOT YET IMPLEMENTED**
**Parallel-safe:** No

> **Why deferred:** US-005 requires Spec 002 US-008 ("member cannot sustain even
> `minDepositPerRound` and is reallocated out of a circle") to be designed and
> implemented first. US-008 is not in Spec 002 v1.0 and has no task in the 002 spec.
> Until the reallocation trigger, exit mechanics, and replacement-member queue are
> defined in Spec 002, US-005 cannot be implemented without risk of incompatible
> interfaces.
>
> Additionally, three open questions in spec.md directly block design decisions:
> - **OQ-001:** Minimum pool depth to accept reallocation coverage (unresolved)
> - **OQ-002:** Coverage window length (default 3 rounds, but not ratified)
> - **OQ-003:** Lock duration matching strategy for deployed capital (unresolved)

---

## Objective

When a member cannot sustain even `minDepositPerRound` and is reallocated out of a
circle, the Safety Net Pool **temporarily covers the vacated slot** for up to
`COVERAGE_WINDOW_ROUNDS` (OQ-002 default: 3) to keep the circle running while a
replacement is matched. If a replacement joins, they absorb the slot and coverage ends.
If no replacement is found within the window, the circle adjusts to N-1 members and the
pool's commitment is released.

---

## Pre-conditions (must be resolved before this task begins)

- [ ] **PRE-01** Spec 002 US-008 is designed and has a task: defines the trigger
  (`checkAndReallocate` or equivalent), the exit mechanics for the reallocated member
  (obligation release, balance handling), and the replacement-member queue interface.
- [ ] **PRE-02** OQ-002 is resolved: coverage window length is ratified by Product
  (default 3 rounds is the current proposal).
- [ ] **PRE-03** OQ-001 is resolved: minimum pool depth required for reallocation
  coverage is quantified by the Protocol Economist.
- [ ] **PRE-04** OQ-003 is resolved: lock duration deployment preference is specified
  (or explicitly documented as "no preference in v1").

---

## Acceptance Criteria (from spec.md US-005)

### SavingsCircle — reallocation trigger

- [ ] T001 `checkAndReallocate(uint256 circleId, uint16 slot)` function in
  `contracts/src/core/SavingsCircle.sol` (or equivalent from Spec 002 US-008):
  - Callable permissionlessly when member's balance < `minDepositPerRound` for 2+ consecutive missed rounds
  - Resets the member's `circleObligation` to 0
  - Calls `pool.coverSlot(circleId, slot, contributionPerMember)` to start pool coverage
  - Records `reallocationStartRound[circleId][slot] = circles[circleId].roundsCompleted`
  - Emits `MemberReallocated(circleId, slot, shieldedId)`

### SavingsCircle — coverage window enforcement

- [ ] T002 During `executeRound`, for each slot with active reallocation coverage, increment
  `reallocationRoundsCovered[circleId][slot]` in `contracts/src/core/SavingsCircle.sol`
- [ ] T003 `finalizeReallocation(uint256 circleId, uint16 slot)` — callable after
  `COVERAGE_WINDOW_ROUNDS` with no replacement:
  - Requires `reallocationRoundsCovered >= COVERAGE_WINDOW_ROUNDS` (AC-005-4)
  - Decrements `circles[circleId].memberCount` by 1 (N-1 adjustment)
  - Calls `pool.releaseSlot(circleId, slot)` to end coverage (AC-005-5)
  - Emits `CircleShrunk(circleId, newMemberCount)`
- [ ] T004 `joinAsReplacement(uint256 circleId, uint16 slot, bytes calldata balanceProof)`:
  - Callable by any eligible member during the coverage window (AC-005-3)
  - Joins the reallocated slot, calls `pool.releaseSlot(circleId, slot)` to end coverage
  - Sets appropriate `circleObligation` for the replacement

### SafetyNetPool — reallocation-specific coverage

- [ ] T005 Verify `coverSlot` (existing, task-01) is sufficient for reallocation use case
  or add a `coverReallocatedSlot` variant if reallocation coverage semantics differ from
  pause coverage (e.g., duration-bounded vs indefinite)
- [ ] T006 Add `reallocationCoverages` mapping if reallocation coverage must be tracked
  separately from pause coverage for accounting purposes:
  ```solidity
  mapping(uint256 circleId => mapping(uint16 slot => uint8 roundsCovered)) public reallocationCoverages;
  ```

### Pool depth check for reallocation

- [ ] T007 Before accepting reallocation coverage (`checkAndReallocate`), verify
  `pool.getAvailableCapital() >= contributionPerMember × COVERAGE_WINDOW_ROUNDS`
  Revert `InsufficientPoolDepthForReallocation(available, required)` if insufficient
  (AC-005-1 — pool must have capacity for the full window upfront)

### Tests

- [ ] T008 Unit test `test_checkAndReallocate_pausesSlotAndStartsPoolCoverage`
- [ ] T009 Unit test `test_finalizeReallocation_shrinksCircle_afterWindowExpires`
- [ ] T010 Unit test `test_joinAsReplacement_endsPoolCoverage`
- [ ] T011 Unit test `test_finalizeReallocation_revertsBeforeWindowExpires`
- [ ] T012 Unit test `test_checkAndReallocate_revertsInsufficientPoolDepth`
- [ ] T013 Integration test `test_reallocation_fullLifecycle` in `contracts/test/integration/ReallocationIntegration.t.sol`:
  - 4-member circle, member B reallocated after 2 missed rounds
  - Pool covers slot B for 3 rounds
  - Round 4: replacement joins slot B → pool releases, circle continues at N=4
  - Round 5: original 3 members complete normally

---

## Output Files

- `contracts/src/core/SavingsCircle.sol` (modified — `checkAndReallocate`, `finalizeReallocation`, `joinAsReplacement`, `reallocationStartRound`)
- `contracts/src/core/SafetyNetPool.sol` (modified — `reallocationCoverages` if needed)
- `contracts/test/unit/SavingsCircle.t.sol` (modified — reallocation tests)
- `contracts/test/integration/ReallocationIntegration.t.sol` (new)

---

## Key Invariants

- Pool coverage of a reallocated slot is **time-bounded** (`COVERAGE_WINDOW_ROUNDS`).
  Unlike pause coverage (which is indefinite until the member resumes), reallocation
  coverage has a hard deadline after which the circle shrinks.
- `payoutReceived[circleId][slot]` remains `false` for a reallocated slot — it is still
  eligible for VRF selection during the coverage window (pool covers the contribution).
- If the circle shrinks to N-1, the invariant "every member receives the pool exactly
  once" still holds for the N-1 remaining members. The reallocated member forfeits their
  turn.
- Pool capital released at `finalizeReallocation` or `joinAsReplacement` returns to
  `getAvailableCapital()` for future coverage use (AC-005-5).

---

## Open Questions (must close before implementation)

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-002 | Coverage window: how many rounds before N-1? | Product | Open |
| OQ-001 | Min pool depth for reallocation coverage | Protocol Economist | Open |
| OQ-003 | Lock duration deployment preference | Protocol Economist | Open |
| OQ-006 | Should the reallocated member's accumulated `safetyNetDebtShares` (if any) be cleared or transferred to the replacement member? | Protocol Architect | New / Open |
