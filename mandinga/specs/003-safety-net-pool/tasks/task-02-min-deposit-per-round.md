# Task 003-02 — Minimum Installment Gap Coverage

**Spec:** 003 — Safety Net Pool (v1.0) — US-003 + US-006
**Milestone:** 5
**Status:** Pending
**Estimated effort:** 10 hours
**Dependencies:** Task 003-01 (SafetyNetPool v1), Task 002-01 (SavingsCircle), Task 001-02 (SavingsAccount)
**Parallel-safe:** No

> **Privacy assumption:** OQ-004 is treated as deferred. In this task, `safetyNetDebtShares`
> is stored directly on the position (no ZK proof). Full shielding is a v3 concern once
> Spec 005 selects the privacy technology.

---

## Objective

Enable members to join a circle using the **minimum installment option**: they pay
`minDepositPerRound` per round and the Safety Net Pool covers the difference
(`depositPerRound − minDepositPerRound`). The member accumulates `safetyNetDebtShares`
that will be settled atomically at payout time (Task 003-03).

This task also implements the **pool depth pre-check** (US-006): a circle can only
accept minimum-installment members if the pool has sufficient undeployed capital to
back the full duration of gaps.

---

## Context

### Current state (after Task 003-01)

| Contract | Relevant state |
|---|---|
| `SavingsCircle.Circle` | `contributionPerMember`, no `minDepositPerRound` |
| `ISavingsAccount.Position` | `balance`, `circleObligation`, no `safetyNetDebtShares` |
| `SafetyNetPool` | `coverSlot` / `releaseSlot` for paused members; no gap tracking |

### Target state after this task

| Contract | New state |
|---|---|
| `SavingsCircle.Circle` | + `minDepositPerRound` (0 = feature disabled) |
| `SavingsCircle` | + `usesMinInstallment[circleId][shieldedId]` mapping |
| `ISavingsAccount.Position` | + `safetyNetDebtShares` field |
| `ISavingsAccount` | + `addSafetyNetDebt`, `getSafetyNetDebtShares` |
| `SavingsAccount` | implements new functions |
| `SafetyNetPool` | + `coverGap(circleId, slot, memberId, gap)` + `gapCoverages` tracking |

---

## Acceptance Criteria

### SavingsCircle — circle formation

- [ ] T001 `createCircle` accepts optional `minDepositPerRound` parameter (0 = disabled)
- [ ] T002 Validation when `minDepositPerRound` is non-zero:
  - `minDepositPerRound < contributionPerMember`; revert `InvalidMinDeposit`
  - `minDepositPerRound >= MIN_MIN_DEPOSIT` (constant = `1e6`, i.e. 1 USDC in 6-decimal); revert `MinDepositTooLow`
  (A 1-wei minimum is intentionally blocked — trivial gaps offer no meaningful savings and waste pool gas.)
- [ ] T003 Pool depth pre-check at `joinCircle` for a member who calls `activateMinInstallment` (AC-006-1):
  ```
  gap              = contributionPerMember − minDepositPerRound
  nAlreadyJoined   = count of members in this circle with usesMinInstallment == true
  required         = (nAlreadyJoined + 1) × gap × memberCount
  available        = pool.getAvailableCapital()
  require(available >= required, InsufficientPoolDepth(available, required))
  ```
  The check accounts for all min-installment members at once (CHK021): each member needs coverage
  for `memberCount` rounds; the pool must hold enough for all of them simultaneously.
  Note: `memberCount` equals the total slots, regardless of how many rounds have been played; the
  pool commits worst-case (all remaining rounds for all min-installment members).
- [ ] T004 New mapping `usesMinInstallment[circleId][shieldedId]` — set to `true` by
  `activateMinInstallment(circleId)`, callable by any member before circle activation:
  - Revert `CircleAlreadyActive(circleId)` if `circles[circleId].state != CircleState.FORMING`
  - Lifecycle: if a min-installment member is later **paused** mid-circle, the `usesMinInstallment`
    flag is NOT cleared — it persists through pause and resume. When the member resumes paying
    `minDepositPerRound`, the pool continues covering their gap in subsequent rounds (same debt
    ledger). If they cannot pay even `minDepositPerRound`, the existing `checkAndPause` path applies.

### SavingsCircle — round execution

- [ ] T005 Before VRF request in `executeRound`, iterate all slots and call `pool.coverGap` for each
  active min-installment member not yet paid (pseudocode):
  ```solidity
  uint256 gap = circles[circleId].contributionPerMember - circles[circleId].minDepositPerRound;
  for (uint16 s = 0; s < circles[circleId].memberCount; s++) {
      bytes32 mid = _members[circleId][s];
      if (!usesMinInstallment[circleId][mid]) continue; // full-installment member — skip (CHK005)
      if (payoutReceived[circleId][s]) continue;        // already received payout — skip
      if (pausedSlots[circleId][s]) continue;           // paused — gap covered by existing pause path
      pool.coverGap(circleId, s, mid, gap);
  }
  ```
  **Invariant (CHK035):** `pool.coverGap` MUST always be called for each eligible min-installment
  member before `requestRandomWords`. Any future refactor of `executeRound` must preserve this order.
- [ ] T006 If `pool.coverGap` reverts with `InsufficientAvailableCapital` mid-circle (pool drained),
  catch the revert and call `_pauseSlot(circleId, slot)` for that member instead of reverting
  `executeRound`. This reuses the same internal pause logic as `checkAndPause` — the member is
  flagged as paused and excluded from VRF selection that round. "Auto-pause" = `_pauseSlot` (CHK010).

### ISavingsAccount / SavingsAccount — new fields and functions

- [ ] T007 [P] Add `safetyNetDebtShares uint256` to `ISavingsAccount.Position` struct in `contracts/src/interfaces/ISavingsAccount.sol`
- [ ] T008 [P] Add `addSafetyNetDebt(bytes32 shieldedId, uint256 shares)` to `ISavingsAccount` interface — callable only by `SafetyNetPool`; emits `SafetyNetDebtAdded(shieldedId, shares)`
- [ ] T009 [P] Add `getSafetyNetDebtShares(bytes32 shieldedId) external view returns (uint256)` to `ISavingsAccount` interface
- [ ] T010 Implement `addSafetyNetDebt` in `contracts/src/core/SavingsAccount.sol` with `onlySafetyNetPool` modifier; invariant: `safetyNetDebtShares` does not affect `balance >= circleObligation` check (it is a separate ledger)
- [ ] T011 Add `safetyNetPool` address to `SavingsAccount` constructor and `onlySafetyNetPool` modifier.
  **Deployment note (CHK008, CHK029, CHK040):**
  - `SavingsAccount` is NOT upgradeable (no proxy). Adding the constructor arg requires a fresh deploy.
  - Deployment order: deploy `SafetyNetPool` first → pass its address to `SavingsAccount` constructor →
    pass `SavingsAccount` address to `SavingsCircle` constructor.
  - `ISavingsAccount.Position` struct change (T007) is storage-append-safe for non-upgradeable
    contracts: `safetyNetDebtShares` is the last field, so no existing slot offsets shift.

### SafetyNetPool — gap coverage

- [ ] T012 [P] Add `gapCoverages` mapping and define the **canonical `GapCoverage` struct** (authoritative definition — task-03 and task-04 reference this, do not redefine it):
  ```solidity
  struct GapCoverage {
      bytes32 memberId;             // shieldedId of the member using min-installment
      uint256 gapPerRound;          // USDC gap covered per round for this slot
      uint256 totalDeployedShares;  // YieldRouter shares committed (grows with yield)
      uint256 lastAccrualTs;        // timestamp of last interest accrual (task-04)
  }
  mapping(uint256 circleId => mapping(uint16 slot => GapCoverage)) public gapCoverages;
  ```
  Notes:
  - `memberId` is stored here so `accrueInterest` (task-04) can call `chargeFromYield` without a callback into `SavingsCircle` (avoids circular dependency).
  - `totalDeployedShares` stores shares, not USDC. The pool-level `totalDeployed` counter (in USDC) is a separate field on `SafetyNetPool` used by `getAvailableCapital()`.
- [ ] T013 Implement `coverGap(uint256 circleId, uint16 slot, bytes32 memberId, uint256 gap) external onlyCircle`
  (4-arg signature — `SavingsCircle` passes `memberId = _members[circleId][slot]` directly,
  avoiding a circular dependency where SafetyNetPool would call back into SavingsCircle):
  - Checks `getAvailableCapital() >= gap`; reverts `InsufficientAvailableCapital`
  - `sharesCommitted = yieldRouter.convertToShares(gap)`
  - `savingsAccount.addSafetyNetDebt(memberId, sharesCommitted)`
  - Updates `gapCoverages[circleId][slot]`: `memberId = memberId` (first call only), `gapPerRound = gap`, `totalDeployedShares += sharesCommitted`, `lastAccrualTs = block.timestamp` (first call only)
  - `totalDeployed += gap` — this is the **same `totalDeployed` counter** used by `coverSlot` (CHK017);
    `getAvailableCapital()` = `totalCapital - totalDeployed` accounts for both gap and pause coverage.
  - `convertToShares` rounds **down** (floor) per ERC4626 standard (CHK033). At settlement,
    `convertToAssets(sharesCommitted)` returns slightly less than `gap` (truncation). This
    difference accrues to the pool as a rounding gain. Accepted known behavior.
  - Emits `GapCovered(circleId, slot, memberId, gap, sharesCommitted)`
- [ ] T014 Add `getGapCoverage(uint256 circleId, uint16 slot) external view returns (GapCoverage memory)`

### Tests

- [ ] T018 Unit test `test_createCircle_withMinDeposit` in `contracts/test/unit/SavingsCircle.t.sol`
- [ ] T019 Unit test `test_createCircle_revertsInvalidMinDeposit` (minDeposit >= contribution)
- [ ] T020 Unit test `test_joinCircle_revertsInsufficientPoolDepth` when pool is empty and member uses min installment
- [ ] T021 Unit test `test_coverGap_incrementsDebtShares` in `contracts/test/unit/SafetyNetPool.t.sol`
- [ ] T022 Unit test `test_coverGap_revertsIfNotCircle`
- [ ] T023 Unit test `test_addSafetyNetDebt_revertsIfNotPool` in `contracts/test/unit/SavingsAccount.t.sol`
- [ ] T024 Integration test `test_minInstallment_threeRounds_debtAccumulates` in `contracts/test/integration/MinInstallmentIntegration.t.sol`:
  - 3-member circle, member A uses min installment ($60 instead of $100)
  - 3 rounds: each round pool covers $40 gap → A accumulates 3 × shares($40) debt
  - Verify `safetyNetDebtShares` on A's position after each round
- [ ] T025 Unit test `test_coverGap_twoMinInstallmentMembers` in `contracts/test/unit/SafetyNetPool.t.sol` (CHK025):
  - Circle with members A and B both using min installment
  - Both call `coverGap` in same round → each slot tracks debt independently
  - `getAvailableCapital()` decreases by `2 × gap`

---

## Output Files

- `contracts/src/interfaces/ISavingsAccount.sol` (modified — Position struct + 2 new functions)
- `contracts/src/core/SavingsAccount.sol` (modified — addSafetyNetDebt + onlySafetyNetPool)
- `contracts/src/core/SavingsCircle.sol` (modified — minDepositPerRound, coverGap calls with memberId, pool depth check)
- `contracts/src/core/SafetyNetPool.sol` (modified — coverGap 4-arg, GapCoverage struct, gapCoverages)
- `contracts/test/unit/SavingsCircle.t.sol` (modified — new min-installment tests)
- `contracts/test/unit/SafetyNetPool.t.sol` (modified — new coverGap tests)
- `contracts/test/integration/MinInstallmentIntegration.t.sol` (new)

---

## Key Invariants

- `safetyNetDebtShares` is a separate ledger — it does NOT count toward the
  `sharesBalance >= circleObligationShares` invariant of SavingsAccount
- Pool can only cover gaps up to `getAvailableCapital()` — never over-commit
- A member using min installment is still ACTIVE (not paused); only if they cannot pay
  even `minDepositPerRound` do they get paused via the existing `checkAndPause` path
- Pool depth check is at `joinCircle`, not post-formation (AC-006-2)
- `coverGap` is `nonReentrant` (inherited from pool) (CHK026). The `executeRound` loop calls
  `coverGap` for multiple members sequentially — reentrancy protection prevents a malicious
  YieldRouter from re-entering the pool between calls.
- `pool.coverGap` is always called before `requestRandomWords` in `executeRound` — this is
  a contract invariant; any refactor must preserve it (CHK035).

---

## Notes

- `SavingsCircle` currently takes `ICircleBuffer` in its constructor; it also needs
  a reference to `ISafetyNetPool` (a richer interface) for gap coverage calls.
  Decision: add a second immutable `ISafetyNetPool pool` address to the constructor
  alongside the existing `ICircleBuffer buffer`. The task-03 `ISafetyNetPool` interface
  (T011) will include `coverGap`, `coverSlot`, `releaseSlot`, and `settleGapDebt`.
- **CHK015 decision:** `coverGap` uses the 4-arg signature
  `coverGap(uint256 circleId, uint16 slot, bytes32 memberId, uint256 gap)`.
  `SavingsCircle` passes `memberId = _members[circleId][slot]` in the call, so
  `SafetyNetPool` never needs to call back into `SavingsCircle`.
  `ISavingsCircle.sol` is **not needed** — T015, T016, T017 were removed.
