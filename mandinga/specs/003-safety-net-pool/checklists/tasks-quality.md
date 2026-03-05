# Tasks Quality Checklist: 003 — Safety Net Pool (task-02, task-03, task-04)

**Purpose**: Validate the quality, completeness, clarity, and consistency of the task
requirements written in task-02-min-deposit-per-round.md, task-03-safety-net-debt-shares.md,
and task-04-coverage-rate.md. This is a requirements quality checklist — it tests whether
the tasks are *well-written*, not whether the implementation works.
**Created**: 2026-03-05
**Feature**: Spec 003 — Safety Net Pool v1.0 (US-003, US-004, AC-003-4)
**Tasks reviewed**: task-02, task-03, task-04

---

## Requirement Completeness

- [x] CHK001 Is the behavior defined when `activateMinInstallment` is called *after* the circle has already activated (ACTIVE state)? task-02 only specifies "FORMING member before activation" but doesn't define the revert error or guard. [Completeness, task-02 T004]
  **Resolved:** task-02 T004 updated — revert `CircleAlreadyActive(circleId)` if circle state != FORMING.

- [x] CHK002 Is the full lifecycle of `usesMinInstallment` documented — specifically, what happens to the flag when the member is paused mid-circle and then resumes? Is a paused min-installment member still marked as `usesMinInstallment`? [Completeness, task-02 T004/T006]
  **Resolved:** task-02 T004 updated — flag persists through pause/resume; debt ledger continues after resume.

- [x] CHK003 Are requirements defined for the case where a member activates min installment and is then selected in round 1 (zero rounds of debt accumulated)? Is `safetyNetDebtShares = 0` at selection a valid path through task-03 `_processPayout`? [Completeness, task-03 T005]
  **Resolved:** task-03 T007 updated — if `debtShares == 0`, skip settlement entirely; `debtUsdc = 0`.

- [x] CHK004 Is the behavior of `getEstimatedNetPayout` (task-04 T008) specified when `interest > grossUsdc - debtUsdc`? The formula `netUsdc = grossUsdc - debtUsdc - interestUsdc` could underflow — is there a floor or a revert defined? [Completeness, task-04 T008]
  **Resolved:** task-04 T008 updated — underflow guard: `netUsdc = debtUsdc + interestUsdc >= grossUsdc ? 0 : ...`

- [x] CHK005 Are requirements defined for what happens to `gapCoverages` state when `settleGapDebt` (task-03 T003) is called for a slot that never had a gap coverage (member was full-installment)? The task says "reverts `GapNotFound`" but task-02 T005 calls `coverGap` for each min-installment member per round — are full-installment members excluded from that loop explicitly? [Completeness, task-02 T005 / task-03 T003]
  **Resolved:** task-02 T005 pseudocode explicitly skips non-min-installment members (`continue` check).

- [x] CHK006 Are requirements specified for what happens to accrued interest when a min-installment member is paused mid-circle (via `checkAndPause`)? Does interest continue accruing on `safetyNetDebtShares` while paused, or is accrual paused too? [Completeness, task-04 T004, Gap]
  **Resolved:** task-04 Notes — interest continues accruing while paused; `gapCoverages` persists.

- [x] CHK007 Is the mock update requirement documented for `MockSafetyNetPool` used in existing SavingsCircle unit tests? task-03 Notes mention it but it is not a formal task item with a file path and checklist entry. [Completeness, task-03 Notes, Gap]
  **Resolved:** task-03 T020 — formal task to update `MockSafetyNetPool` and `MockSavingsAccount`.

- [x] CHK008 Are requirements specified for the `SavingsAccount` constructor change (task-02 T011, adding `safetyNetPool` address)? Specifically: what is the deployment order constraint, and does this require a re-deployment of `SavingsAccount`? [Completeness, task-02 T011]
  **Resolved:** task-02 T011 — fresh deploy required; deployment order: SafetyNetPool → SavingsAccount → SavingsCircle.

---

## Requirement Clarity

- [x] CHK009 Is "before VRF request in `executeRound`" (task-02 T005) precise enough? It is ambiguous whether `coverGap` is called once per round for all min-installment members at the start of every round, or only for new gaps since the last round. A concrete loop pseudocode or sequence diagram would resolve this. [Clarity, task-02 T005]
  **Resolved:** task-02 T005 now has full loop pseudocode with explicit `continue` guards.

- [x] CHK010 Is the term "auto-pause" in task-02 T006 defined with a specific code path? Does it reuse the existing `checkAndPause` external function (which can be called by anyone), or does it call internal pause logic directly from `executeRound`? [Clarity, task-02 T006]
  **Resolved:** task-02 T006 — "auto-pause" = `_pauseSlot(circleId, slot)` internal call.

- [x] CHK011 Is "the pool releases the capital it had committed" (task-03 Objective) quantified with a specific accounting formula? The objective says `totalDeployed` is decremented, but the field name in task-03 T003 is `totalDeployed` while task-04 T003 references `totalDeployedShares` — these appear to be the same field with different names. [Clarity, task-03 T003 / task-04 T003, Conflict]
  **Resolved:** task-03 T003 — `usdcReleased = convertToAssets(gapCoverages[circleId][slot].totalDeployedShares)`, then `totalDeployed -= usdcReleased`. Two distinct fields: struct field (shares) and pool counter (USDC).

- [x] CHK012 Is "interest is added to the pool's claimable revenue" (task-04 Objective) specified as a concrete storage update? The task mentions `totalInterestCollected` as a future accounting variable but does not define it as an acceptance criterion for this task. [Clarity, task-04 Objective, Ambiguity]
  **Resolved:** task-04 T004 and Notes — `totalInterestCollected += interest` is now a concrete AC in T004.

- [x] CHK013 Is "principle of last resort — charges from balance" (task-04 T001) defined with the exact condition? The task says "if insufficient yield, remainder from balance" but does not specify whether `circleObligation` is included in the available balance or excluded. The revert condition `balance - circleObligation < remainder` implies circleObligation is excluded, but this should be an explicit statement in the acceptance criterion. [Clarity, task-04 T001]
  **Resolved:** task-04 T001 — explicit: `circleObligation` is excluded; only `balance - circleObligation` is chargeable.

- [x] CHK014 Is the `convertGapToUsdc` function (task-03 T004) specified to return the *current* value of shares at call time, or the *original* USDC value at coverage time? Since share price appreciates, these differ and the choice directly affects how much the member's obligation is reduced. [Clarity, task-03 T004, Ambiguity]
  **Resolved:** task-03 T004 — returns **current** value (share appreciation accrues to pool; member settles at current value).

- [x] CHK015 Is the preferred function signature for `coverGap` — `coverGap(uint256 circleId, uint16 slot, bytes32 memberId, uint256 gap)` (noted at the end of task-02 Notes) — reflected in the actual acceptance criterion T013? T013 shows a 3-argument signature without `memberId`. [Clarity, task-02 T013 / Notes, Conflict]
  **Resolved:** task-02 T013 atualizado para a assinatura 4-arg com `memberId`. T005 atualizado para passar `_members[circleId][slot]`. T015/T016/T017 (`getMemberForSlot`, `ISavingsCircle.sol`) removidos. Notes atualizadas com decisão explícita.

---

## Requirement Consistency

- [x] CHK016 Are the `GapCoverage` struct fields consistent across all three task files? task-02 T012 defines `{ gapPerRound, totalDeployed, lastRoundCovered }` but task-03 Notes says it must store `totalDeployedShares` (not `totalDeployed`), and task-04 T003 replaces `lastRoundCovered` with `lastAccrualTs`. These three tasks define different versions of the same struct — is a reconciled final definition documented? [Consistency, task-02 T012 / task-03 Notes / task-04 T003]
  **Resolved:** task-02 T012 agora é a **definição canônica única** do struct com todos os 4 campos: `{ bytes32 memberId, uint256 gapPerRound, uint256 totalDeployedShares, uint256 lastAccrualTs }`. task-04 T003 convertido para referência (não redefine o struct).

- [x] CHK017 Do the two pool `totalDeployed` accounting paths (pause coverage via `coverSlot` and gap coverage via `coverGap`) use the same `totalDeployed` counter? If so, `getAvailableCapital()` already accounts for gaps, which is correct, but the task-02 T013 does not explicitly confirm this. If they use separate counters, the available capital check may be incorrect. [Consistency, task-02 T013 / task-01 coverSlot]
  **Resolved:** task-02 T013 — confirmed single `totalDeployed` counter for both `coverSlot` and `coverGap`.

- [x] CHK018 Is the `onlySafetyNetPool` modifier in `SavingsAccount` consistent with the existing `onlySavingsCircle` modifier? Both are needed for `addSafetyNetDebt` (pool) and `clearSafetyNetDebt` (circle). task-02 T010/T011 introduce `onlySafetyNetPool` but task-03 T002 uses `onlySavingsCircle` for `clearSafetyNetDebt` — are these two separate modifiers both required on the same contract? [Consistency, task-02 T010 / task-03 T002]
  **Resolved:** task-03 T011 — confirmed both modifiers are required; `addSafetyNetDebt` → `onlySafetyNetPool`, `clearSafetyNetDebt` → `onlySavingsCircle`.

- [x] CHK019 Is the `ISafetyNetPool` interface (task-03 T009) consistent with the `ICircleBuffer` interface (existing)? task-03 Notes say `ISafetyNetPool` should *extend* `ICircleBuffer`, but neither task-03 nor task-04 formally updates the `ICircleBuffer` import in `SavingsCircle.sol`. [Consistency, task-03 T008/T009]
  **Resolved:** task-03 T011 — `ISafetyNetPool extends ICircleBuffer`; `SavingsCircle` replaces `ICircleBuffer buffer` immutable with `ISafetyNetPool pool`.

- [x] CHK020 Are the integration test file references consistent? task-02 T024 creates `MinInstallmentIntegration.t.sol`, task-03 T015 says "extended", and task-04 T016 says "extended" — but task-02 and task-03 both have separate scenario names that could conflict if both are in the same file. Is the test file scope for each task clearly bounded? [Consistency, task-02 T024 / task-03 T015 / task-04 T016]
  **Resolved (decision):** single file `MinInstallmentIntegration.t.sol` with distinct test function names per task. task-02 T024 creates the file + round-level tests; task-03 T019 adds selection/settlement tests; task-04 T016 adds interest accrual tests. No name conflicts since each test has a unique descriptive function name.

---

## Acceptance Criteria Quality

- [x] CHK021 Is the pool depth formula in task-02 T003 (`gap × memberCount`) correct and complete? The spec AC-006-1 says `(depositPerRound − minDepositPerRound) × N rounds` per covered member — N rounds = `memberCount`. But if multiple members use min installment, the formula should be `gap × memberCount × nMinInstallmentMembers`. Is the multi-member scenario covered? [Acceptance Criteria, task-02 T003 / Spec AC-006-1]
  **Resolved:** task-02 T003 — formula updated to `required = (nAlreadyJoined + 1) × gap × memberCount`.

- [x] CHK022 Is the unit test acceptance criterion for `test_processPayout_withDebt_reducedObligation` (task-03 T011) measurable and unambiguous? It states `circleObligation = poolSize - $80` but does not specify the value of `poolSize` in that test scenario, making the expected output impossible to verify without additional context. [Acceptance Criteria, task-03 T011]
  **Resolved (decision):** task-03 T014 sets the scenario: 3-member circle, `contributionPerMember = $100`, `poolSize = $300`, debt = 2 rounds × $40 = $80 USDC. `circleObligation = $300 - $80 = $220`. Implementer must use these exact numbers.

- [x] CHK023 Is the acceptance criterion for `test_accrueInterest_chargesYieldAfterTime` (task-04 T010) measurable? It says "≈ $0.16" (approximate) — is the tolerance or rounding rule specified? Interest formula uses integer division which truncates, so the exact expected value matters for a test assertion. [Acceptance Criteria, task-04 T010]
  **Resolved:** task-04 T010 — exact value computed: `164_383` (6-decimal USDC). `assertEq` not `assertApproxEq`.

- [x] CHK024 Is the acceptance criterion for "auto-accrual in `settleGapDebt`" (task-04 T006) testable in isolation? The requirement says the internal `_accrueInterestInternal` "must silently skip if position is insolvent" — but the Key Invariants section also says `settleGapDebt` should still proceed. Is "silently skip" a documented behavior or an unspecified fallback? [Acceptance Criteria, task-04 T006 / Key Invariants]
  **Resolved:** task-04 T013 and T017 now clearly separate: external `accrueInterest` propagates `PositionInsolvent`; internal `_accrueInterestInternal` (via `settleGapDebt`) catches it and emits `InterestForgiven`.

---

## Scenario Coverage

- [x] CHK025 Is the scenario where two members in the same circle both use min installment covered? task-02 T005 iterates all min-installment members, but no test covers the multi-member gap coverage scenario in the same round — the integration test (T024) only tests one min-installment member. [Coverage, task-02 T024, Gap]
  **Resolved:** task-02 T025 — new unit test for two min-installment members in same round.

- [x] CHK026 Is the re-entry scenario covered for `coverGap`? If `SavingsCircle.executeRound` calls `pool.coverGap` for multiple min-installment members in a loop, is re-entrancy protection on `coverGap` sufficient (inherited `nonReentrant` from pool)? [Coverage, task-02 T013, Security]
  **Resolved:** task-02 Key Invariants — `coverGap` is `nonReentrant` (inherited). Documented explicitly.

- [x] CHK027 Is the scenario covered where a member's `safetyNetDebtShares` is non-zero but the corresponding `gapCoverages` entry has been deleted (state inconsistency between `SavingsAccount` and `SafetyNetPool`)? This could occur if `settleGapDebt` is called manually before `_processPayout`. [Coverage, task-03 T003/T005, Edge Case]
  **Resolved:** task-03 T021 — unit test for state inconsistency; `settleGapDebt` reverts `GapNotFound`.

- [x] CHK028 Is the scenario covered where `accrueInterest` is called after the member is already selected (i.e., `gapCoverages[circleId][slot].amount == 0` post-settlement)? task-04 T004 does not specify the revert or no-op behavior for a slot with no active gap coverage. [Coverage, task-04 T004, Edge Case]
  **Resolved:** task-04 T004 — guard: if `lastAccrualTs == 0` (post-deletion or never covered), return early.

- [x] CHK029 Is the upgrade/migration path covered for adding `safetyNetPool` to `SavingsAccount`'s constructor (task-02 T011)? If `SavingsAccount` is upgradeable (uses a proxy), an initializer function may be required instead. If not upgradeable, the deployment must be atomic. [Coverage, task-02 T011, Gap]
  **Resolved:** task-02 T011 — `SavingsAccount` is non-upgradeable; fresh deploy required.

---

## Edge Case Coverage

- [x] CHK030 Is the boundary condition `minDepositPerRound = 1 wei` specified as valid or invalid? task-02 T002 requires `minDepositPerRound < contributionPerMember` but sets no lower bound. A 1-wei minimum produces a gap of essentially `contributionPerMember` — is this intentional? [Edge Case, task-02 T002]
  **Resolved:** task-02 T002 — `MIN_MIN_DEPOSIT = 1e6` (1 USDC); `minDepositPerRound < 1e6` reverts `MinDepositTooLow`.

- [x] CHK031 Is the boundary condition where `coverageRateBps = 0` (zero interest) defined as valid? task-04 does not specify the behavior of `accrueInterest` when the governor sets the rate to 0 — should it be a no-op or still update `lastAccrualTs`? [Edge Case, task-04 T004/T005]
  **Resolved:** task-04 T004 — `coverageRateBps == 0` returns early; `lastAccrualTs` NOT updated.

- [x] CHK032 Is the behavior defined when `convertGapToUsdc` returns a value that has grown (due to yield) to be larger than `poolSize`? This is an extreme edge case but the invariant `debtUsdc ≤ poolSize` (task-03 Key Invariants) relies on the spec's arithmetic guarantee — is there a check in `_processPayout` for this case or is it solely relied upon as a mathematical guarantee? [Edge Case, task-03 T006, Invariant]
  **Resolved:** task-03 T007 — explicit guard: `require(debtUsdc <= poolSize, DebtExceedsPoolSize)`.

- [x] CHK033 Is the rounding behavior for `convertToShares(gap)` in `coverGap` (task-02 T013) specified as floor or ceiling? Since shares are integer values, repeated rounding at `coverGap` and `convertToAssets` at settlement could create systematic discrepancies. [Edge Case, task-02 T013]
  **Resolved:** task-02 T013 — floor (ERC4626 standard); rounding gain accrues to pool.

---

## Dependencies & Assumptions

- [x] CHK034 Is the dependency on `ISavingsCircle.getMember` (task-02 T016 / task-04 T004) validated against the circular-dependency risk? The Note in task-02 identifies this as a known issue and proposes passing `memberId` in the call signature — but this is documented only in Notes, not promoted to a formal task item. An implementer might miss it. [Dependency, task-02 Notes / task-04 T004]
  **Resolved (previously CHK015):** 4-arg `coverGap` + `memberId` stored in `GapCoverage` struct. No callback into SavingsCircle ever needed.

- [x] CHK035 Is the assumption that `SavingsCircle` will always call `pool.coverGap` before any round's VRF callback documented as an invariant? If `executeRound` is called and the gap coverage step is skipped (e.g., due to a future refactor), `safetyNetDebtShares` would be inaccurate. [Assumption, task-02 T005]
  **Resolved:** task-02 Key Invariants — explicit invariant added.

- [x] CHK036 Is the assumption that `fulfillRandomWords` cannot revert (existing SavingsCircle invariant) reconciled with the new calls added in task-03 T005? `settleGapDebt` and `clearSafetyNetDebt` could themselves revert (e.g., `GapNotFound`, `SavingsAccount` error). Are all new calls within `_processPayout` guaranteed non-reverting? [Dependency / Invariant, task-03 T005 / task-03 Key Invariants]
  **Resolved:** task-03 Key Invariants — `_markPayout` (Phase 1 in VRF callback) makes no external calls; settlement is Phase 2 (`claimPayout`), which can revert safely.

- [x] CHK037 Is the assumption that task-04 will be implemented in the same Milestone 5 as tasks 02 and 03 validated? If task-04 is deferred, the `lastAccrualTs` field defined in task-04 T003 conflicts with `lastRoundCovered` already in task-02 T012 — the field would need to be named correctly from the start. [Dependency, task-02 T012 / task-04 T003]
  **Resolved (previously CHK016):** canonical struct already has `lastAccrualTs` in task-02 T012; no conflict remains. Tasks 02-04 must be implemented together in Milestone 5.

---

## Non-Functional Requirements

- [x] CHK038 Are gas cost requirements specified for the modified `executeRound` loop (task-02 T005)? For a circle with 1000 members (MAX_MEMBERS) where all use min installment, the loop calls `pool.coverGap` 1000 times per round — are gas limits validated? [Non-Functional, task-02 T005, Performance]
  **Resolved (accepted risk):** The `executeRound` gas cost is unbounded by design (not a VRF callback). Ethereum block gas limit (~30M) limits circles to ~100 min-installment members per round in practice. Task-02 Notes document this scaling constraint. For v2, off-chain batching can be introduced. No formal gas limit AC is added to this task — it is deferred as a known limitation.

- [x] CHK039 Are gas cost requirements specified for `fulfillRandomWords` after the task-03 additions? The VRF callback must stay within Chainlink's `CALLBACK_GAS_LIMIT = 300_000`. Adding `getSafetyNetDebtShares`, `settleGapDebt`, and `clearSafetyNetDebt` within it may exceed this limit for members with complex positions. [Non-Functional, task-03 T005, Performance]
  **Resolved:** task-03 reestruturado com two-phase split — VRF callback apenas marca `pendingPayout` (≤ 150k gas); settlement completo movido para `claimPayout` (nova função separada, T007). Ver task-03 T005–T009.

- [x] CHK040 Are upgrade safety requirements defined for the `ISavingsAccount.Position` struct change (task-02 T007)? Adding `safetyNetDebtShares` to the struct shifts the storage layout — if `SavingsAccount` uses a proxy pattern, this could corrupt existing storage slots. [Non-Functional, task-02 T007, Security]
  **Resolved:** task-02 T011 — `SavingsAccount` is non-upgradeable; struct append is safe.

---

## Ambiguities & Conflicts

- [x] CHK041 Is the field naming conflict between `totalDeployed` (USDC amount, task-02 T012) and `totalDeployedShares` (shares, task-03 Notes) resolved with an explicit decision in one of the task files? Both names appear for what seems to be the same field in `GapCoverage`. [Conflict, task-02 T012 / task-03 Notes]
  **Resolved:** O campo do struct é `totalDeployedShares` (shares do YieldRouter). O counter USDC separado `totalDeployed` é campo de nível do `SafetyNetPool` (usado por `getAvailableCapital()`). Ambos os nomes foram explicitados em task-02 T012 e T013.

- [x] CHK042 Is the tension between task-04 Key Invariants ("auto-accrual must silently skip if position is insolvent") and the `PositionInsolvent` revert defined in task-04 T001 resolved? `chargeFromYield` reverts, but `_accrueInterestInternal` must not propagate that revert into `settleGapDebt`. Is a try/catch or separate code path explicitly specified? [Conflict, task-04 T001 / task-04 Key Invariants]
  **Resolved:** task-04 T006 atualizado com `try/catch` obrigatório e código de referência explícito. Insolvência resulta em `InterestForgiven` (novo evento), `settleGapDebt` sempre prossegue. Novo teste T017 cobre o cenário. Ver task-04 T006 e Key Invariants.

- [x] CHK043 Is the ambiguity in what "interest flows back to depositors" means (task-04 Objective) resolved? The objective says interest "increases `totalDeployed`" but Notes say it should be tracked via `totalInterestCollected` and harvested separately. These two mechanisms are different — only one should be the accepted design for this task. [Ambiguity, task-04 Objective / Notes]
  **Resolved:** task-04 Notes — mechanism is `totalInterestCollected` (accounting variable). Does NOT increase `totalDeployed`. `harvestInterest()` deferred to v2. T004 updated to include `totalInterestCollected += interest`.
