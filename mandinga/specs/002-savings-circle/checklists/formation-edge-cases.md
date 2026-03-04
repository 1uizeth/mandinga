# Formation & Safety Net Pool Edge Cases Checklist: Savings Circle

**Purpose**: Validate that the Spec 002 (Savings Circle) and Spec 003 (Safety Net Pool) requirements adequately cover the boundary conditions and edge cases surfaced during simulator analysis. Each item tests whether the *requirement* is complete, clear, consistent, and measurable — not whether the implementation works.
**Created**: 2026-03-02
**Feature**: [Spec 002 — Savings Circle](../spec.md) · [Spec 003 — Safety Net Pool](../../003-safety-net-pool/spec.md)
**Trigger**: Edge case analysis from Circle Simulator (`mandinga-yield-scenarios.html`)

---

## Requirement Completeness — Kickoff Algorithm

- [ ] CHK001 — Is the exact formula for computing pool depth requirement at kickoff fully specified, including whether it uses `minDepositPerRound` as declared or always defaults to `depositPerRound / 2`? [Completeness, Spec 002 §US-006, Spec 003 §AC-006-1]

- [ ] CHK002 — Does the spec define what the kickoff algorithm does when a bucket contains a **mix** of self-funded and pool-backed members, and the pool has capital sufficient only for a subset of pool-backed users? Is partial inclusion of backed users defined, or is it all-or-none? [Completeness, Gap — Spec 002 §US-006, Spec 003 §AC-006-1]

- [ ] CHK003 — Are requirements defined for the case where the pool has `$0` capital but the queue contains only self-funded (`mode = self`) members? The spec implies circles should form freely — is this explicitly stated? [Completeness, Spec 003 §AC-006-3]

- [ ] CHK004 — Is the relationship between `minDepositPerRound` and the pool depth formula explicitly specified? The simulator uses `poolBacked × (N-1) × D/2` as worst-case; does the spec mandate this formula or a different one? [Clarity, Spec 003 §AC-006-1]

- [ ] CHK005 — Are requirements defined for how the kickoff algorithm prioritises self-funded members over pool-backed members when pool depth is insufficient for a full candidate N? [Gap — Spec 002 §US-006]

---

## Requirement Completeness — Duration & N Bounds

- [ ] CHK006 — Is the minimum valid `duration` defined to prevent degenerate `roundLength` values (e.g., sub-day rounds from short duration + high N)? OQ-001 in Spec 002 flags this as open — is a floor needed before implementation? [Gap, Spec 002 §OQ-001]

- [ ] CHK007 — Is the maximum valid `duration` defined to prevent unreasonably long locks? Without a ceiling, a member could declare a 50-year duration, creating `roundLength` intervals that make circle formation impractical. [Gap, Spec 002 §OQ-001]

- [ ] CHK008 — Is the minimum viable circle size (`minN`) defined as a protocol constant, a governance parameter, or left to the kickoff algorithm? The spec references the formation threshold (70%) but does not appear to define a hard minimum N floor. [Clarity, Spec 002 §AC-006-2]

- [ ] CHK009 — When `duration / N` produces a non-integer `roundLength`, does the spec define the rounding behaviour (floor, ceiling, nearest)? A 10-month duration with N=6 produces 1.67 months per round — is this addressed? [Clarity, Gap — Spec 002 §AC-006-2]

---

## Requirement Completeness — Safety Net Pool Bootstrapping

- [ ] CHK010 — Is there a specified minimum pool depth required before any circle with pool-backed members can be formed? OQ-001 in Spec 003 flags this as open — without an answer, the protocol cannot have a launch sequence. [Gap, Spec 003 §OQ-001]

- [ ] CHK011 — Does the spec define the go-to-market sequencing: should Phase 1 launch accept only self-funded circles (pool = $0), with pool-backed circles enabled only after the pool reaches a minimum depth? [Gap, Spec 003 §OQ-001]

- [ ] CHK012 — Are requirements defined for what happens when new pool-backed members join a queue while the pool is fully committed to existing circles? Does the intent stay in queue indefinitely, or is there a wait-time limit before the member is prompted to switch to self-funded? [Gap, Spec 002 §US-006, Spec 003 §US-006]

---

## Requirement Clarity — Viability Threshold

- [ ] CHK013 — Is "beats solo saving" defined precisely? The simulator uses `lumpY(pool, holdMonths, mRate) - dripY(D, N-p, pr) > 0.005` as the threshold — does the spec define the exact comparison, including whether it's a strict inequality and what epsilon (if any) is used? [Clarity, Spec 002 §AC-006-2]

- [ ] CHK014 — Is the 70% formation threshold (positions that beat solo saving) described as a hard requirement or a soft heuristic? Can governance reduce it to 0% (always form, regardless of yield advantage)? Are floor/ceiling bounds defined? [Clarity, Spec 002 §AC-006-3]

- [ ] CHK015 — When the APY is 0% (or near 0%), the math produces zero yield advantage for all positions — does the spec define the expected behaviour of the kickoff algorithm in this degenerate case? [Edge Case, Gap — Spec 002 §US-006]

---

## Requirement Clarity — Pool Exhaustion During Active Rounds

- [ ] CHK016 — Does the spec define what happens when the Safety Net Pool becomes fully depleted **after** a circle has already formed but **before** all covered members have been selected? Is the pool commitment irrevocable at formation, or can the pool be reclaimed if a covered member self-funds? [Clarity, Gap — Spec 003 §US-003, §US-004]

- [ ] CHK017 — Are requirements defined for the case where pool capital is committed (reserved) at formation but the covered member reaches selection before using all reserved rounds? Does the uncommitted portion return to available immediately at selection, or only at circle completion? [Clarity, Spec 003 §AC-004-5]

- [ ] CHK018 — Is there a maximum `poolCommit` cap (as a percentage of pool total) to prevent a single large circle from committing 100% of pool capital and blocking all other circles? [Gap, Spec 003 §US-006]

---

## Requirement Consistency — Spec 002 vs Spec 003 Cross-Reference

- [ ] CHK019 — Spec 002 §AC-006-1 references the pool depth check as a formation prerequisite, and Spec 003 §AC-006-1 defines the formula. Are these two specs consistent in their formula definition, or does one use `duration × gap` while the other uses `(N-1) × gap`? [Consistency, Spec 002 §AC-006-1 vs Spec 003 §AC-006-1]

- [ ] CHK020 — Spec 002 §US-007 AC-007-4 states interest accrues on `safetyNetDebtShares` "from the member's yield earnings before they accrue to the member's position." Spec 003 §AC-003-4 says "transparent and automatic." Is the exact deduction mechanism — and what happens if yield is insufficient to cover the interest — defined consistently across both specs? [Consistency, Spec 002 §AC-007-4, Spec 003 §AC-003-4]

- [ ] CHK021 — The reallocation mechanic (Spec 002 §US-008) says the pool "may temporarily cover the open slot." Spec 003 §US-005 defines this as a 3-round window. Are these two specs aligned, and is "3 rounds" defined in Spec 002 as well, or does Spec 002 leave the window duration unspecified? [Consistency, Spec 002 §AC-008-3, Spec 003 §AC-005-1]

---

## Scenario Coverage — Reallocation Edge Cases

- [ ] CHK022 — Are requirements defined for a reallocation cascade: a member reallocated to a smaller circle triggers another member in that circle to be unable to sustain even the new minimum? [Coverage, Gap — Spec 002 §US-008]

- [ ] CHK023 — Does the spec define what happens when a member is reallocated but **no smaller circle exists** (either in queue or formable) at any installment amount? Does the member return to standalone savings only, or is there an intermediate state? [Coverage, Spec 002 §AC-008-2]

- [ ] CHK024 — When a member exits and their contributions are returned "minus any `safetyNetDebtShares` owed," does the spec define what happens if `safetyNetDebtShares > total contributions returned` (i.e., the member owes more than they contributed)? Can this happen, and if so, is the net outcome defined? [Edge Case, Gap — Spec 002 §AC-008-5]

- [ ] CHK025 — Are requirements defined for the timing of reallocation: can a member be reallocated in the same round they fail to pay, or only at round boundary? Who triggers the reallocation detection? [Clarity, Gap — Spec 002 §US-008, Spec 003 §US-005]

---

## Scenario Coverage — Selection and Obligation Edge Cases

- [ ] CHK026 — When the selected member has `safetyNetDebtShares > 0`, Spec 002 §AC-002-3 says debt is settled first from gross payout. Is there a requirement defining what happens if `safetyNetDebtShares >= circleAllocation` (i.e., debt equals or exceeds the full payout)? Is this bounded by construction, and if so, where is the proof? [Edge Case, Spec 002 §AC-002-3, Spec 003 §AC-004-3]

- [ ] CHK027 — Does the spec define the order of operations atomically at selection (settle debt → set obligation → credit balance)? Is this a single transaction requirement, and if the transaction reverts midway, what is the recovery state? [Clarity, Spec 002 §AC-002-3, Spec 003 §AC-004-2]

- [ ] CHK028 — Are requirements defined for what happens if the last remaining unselected member cannot pay even `minDepositPerRound` in the final round? Reallocation at the last round seems undefined — the circle cannot be corrected at this stage. [Edge Case, Gap — Spec 002 §US-008]

---

## Non-Functional Requirements — Kickoff Liveness

- [ ] CHK029 — Is there a maximum wait time defined for a queued intent before the protocol is required to act (form a sub-optimal circle, suggest parameter changes, or notify the member)? Without a liveness bound, members could wait indefinitely. [Gap, Spec 002 §AC-006-6]

- [ ] CHK030 — Are gas cost requirements defined for the kickoff algorithm? For large queues (e.g., 50+ users in a bucket), evaluating all candidate N values on-chain may exceed block gas limits — is this addressed? [Non-Functional, Gap — Spec 002 §US-006]

- [ ] CHK031 — Is there a requirement defining the maximum number of simultaneous pool-backed circles the Safety Net Pool is allowed to support, to prevent over-commitment? Or is this handled entirely by the available capital check with no explicit cap? [Non-Functional, Gap — Spec 003 §US-006]

---

## Ambiguities & Open Questions Requiring Resolution Before Implementation

- [ ] CHK032 — OQ-001 (Spec 003): Minimum pool depth for first circle with minimum-installment members is unresolved. Is this a blocker for Milestone 3? If unresolved, what default assumption does the implementation use? [Ambiguity, Spec 003 §OQ-001]

- [ ] CHK033 — OQ-004 (Spec 002): `minDepositPerRound` default as `depositPerRound / 2` — is the 50% floor a protocol constant or governance-configurable? If governance-configurable, does a change to this parameter affect existing active circles? [Ambiguity, Spec 002 §OQ-004]

- [ ] CHK034 — OQ-005 (Spec 002 / Spec 003): Coverage interest rate unresolved. Does the implementation use a placeholder (e.g., fixed 5%) pending the Protocol Economist decision, and if so, is there a migration path if the rate changes post-deployment? [Ambiguity, Spec 002 §OQ-005, Spec 003 §OQ-005]

- [ ] CHK035 — OQ-003 (Spec 002): Duration bucketing/tolerance — when members declare "30 days" vs "1 month," are they placed in the same bucket? Without resolution, the matching queue key `(depositPerRound, duration)` is ambiguous and could fragment demand across near-identical buckets. [Ambiguity, Spec 002 §OQ-003]

---

## Notes

- Items marked `[Gap]` indicate the spec does not currently address the scenario — these require a decision before implementation begins
- Items marked `[Ambiguity]` have a spec entry but the requirement is insufficiently precise for implementation
- Items marked `[Consistency]` reference two spec sections that may contradict or diverge
- Check items off as resolved: `[x]`
- Cross-reference open questions (OQ-*) in each spec when resolving items here
