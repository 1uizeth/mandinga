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
| `SafetyNetPool` | + `coverGap(circleId, slot, gap)` + `gapCoverages` tracking |

---

## Acceptance Criteria

### SavingsCircle — circle formation

- [ ] T001 `createCircle` accepts optional `minDepositPerRound` parameter (0 = disabled)
- [ ] T002 Validation: `minDepositPerRound < contributionPerMember` if non-zero; revert `InvalidMinDeposit`
- [ ] T003 Pool depth pre-check at `joinCircle` for min-installment members (AC-006-1):
  `pool.getAvailableCapital() >= gap × memberCount` where `gap = contributionPerMember − minDepositPerRound`
  Revert `InsufficientPoolDepth(available, required)` if fails
- [ ] T004 New mapping `usesMinInstallment[circleId][shieldedId]` — set to `true` by `activateMinInstallment(circleId)`, callable by any FORMING member before activation

### SavingsCircle — round execution

- [ ] T005 Before VRF request in `executeRound`, iterate all active min-installment members not yet paid and call `pool.coverGap(circleId, slot, gap)` for each — member's `safetyNetDebtShares` accumulates
- [ ] T006 If pool has insufficient capital mid-circle, auto-pause the min-installment member (fallback to existing `checkAndPause` path) rather than reverting `executeRound`

### ISavingsAccount / SavingsAccount — new fields and functions

- [ ] T007 [P] Add `safetyNetDebtShares uint256` to `ISavingsAccount.Position` struct in `contracts/src/interfaces/ISavingsAccount.sol`
- [ ] T008 [P] Add `addSafetyNetDebt(bytes32 shieldedId, uint256 shares)` to `ISavingsAccount` interface — callable only by `SafetyNetPool`; emits `SafetyNetDebtAdded(shieldedId, shares)`
- [ ] T009 [P] Add `getSafetyNetDebtShares(bytes32 shieldedId) external view returns (uint256)` to `ISavingsAccount` interface
- [ ] T010 Implement `addSafetyNetDebt` in `contracts/src/core/SavingsAccount.sol` with `onlySafetyNetPool` modifier; invariant: `safetyNetDebtShares` does not affect `balance >= circleObligation` check (it is a separate ledger)
- [ ] T011 Add `safetyNetPool` address to `SavingsAccount` constructor and `onlySafetyNetPool` modifier

### SafetyNetPool — gap coverage

- [ ] T012 [P] Add `gapCoverages` mapping: `mapping(uint256 circleId => mapping(uint16 slot => GapCoverage)) public gapCoverages` where `GapCoverage { uint256 gapPerRound; uint256 totalDeployed; uint256 lastRoundCovered; }`
- [ ] T013 Implement `coverGap(uint256 circleId, uint16 slot, uint256 gap) external onlyCircle`:
  - Checks `getAvailableCapital() >= gap`; reverts `InsufficientAvailableCapital`
  - Calls `savingsAccount.addSafetyNetDebt(memberId, convertToShares(gap))`
  - `totalDeployed += gap`; updates `gapCoverages`
  - Emits `GapCovered(circleId, slot, gap, shares)`
- [ ] T014 Add `getGapCoverage(uint256 circleId, uint16 slot) external view returns (GapCoverage memory)`
- [ ] T015 Add `getMemberForSlot(uint256 circleId, uint16 slot) internal view` helper — calls `ISavingsCircle(circle).getMember(circleId, slot)`

### Interface changes

- [ ] T016 [P] Create `contracts/src/interfaces/ISavingsCircle.sol` with `getMember(uint256 circleId, uint16 slot) external view returns (bytes32)` — needed by SafetyNetPool to resolve slot → shieldedId
- [ ] T017 Add `SavingsCircle` implements `ISavingsCircle` in `contracts/src/core/SavingsCircle.sol`

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

---

## Output Files

- `contracts/src/interfaces/ISavingsAccount.sol` (modified — Position struct + 2 new functions)
- `contracts/src/interfaces/ISavingsCircle.sol` (new — getMember view)
- `contracts/src/core/SavingsAccount.sol` (modified — addSafetyNetDebt + onlySafetyNetPool)
- `contracts/src/core/SavingsCircle.sol` (modified — minDepositPerRound, coverGap calls, pool depth check)
- `contracts/src/core/SafetyNetPool.sol` (modified — coverGap, gapCoverages, getMemberForSlot)
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

---

## Notes

- `SavingsCircle` currently takes `ICircleBuffer` in its constructor; it also needs
  a reference to `ISafetyNetPool` (a richer interface) for gap coverage calls.
  Consider: use a single contract address cast to both interfaces, or add a second
  immutable `pool` address alongside `buffer`.
- The `ISavingsCircle.getMember` interface creates a circular dependency
  (`SafetyNetPool → ISavingsCircle`, `SavingsCircle → ICircleBuffer`). Resolve by
  passing `circleAddress` to `coverGap` call signature, or have `SavingsCircle` pass
  `shieldedId` alongside `slot` in the `coverGap` call (preferred — avoids callback).
  Preferred signature: `coverGap(uint256 circleId, uint16 slot, bytes32 memberId, uint256 gap)`
