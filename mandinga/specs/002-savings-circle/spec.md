# Spec 002 — Savings Circle

**Status:** Draft
**Version:** 0.4
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 003 (Solidarity Pool), Spec 004 (Yield Engine)

---

## Changelog

**v0.4 (February 2026):**
- **Relaxed AC-001-6:** Entry no longer requires `sharesBalance >= circleAllocation`. The full principal lock requirement was an overcorrection — it required members to already have the full pool amount, eliminating the primary credit utility of the ROSCA mechanism. Replaced with a two-path entry check: (a) self-funded: member has sufficient balance to cover `circleAllocation`; (b) pool-backstopped: member's balance is below `circleAllocation` but the Solidarity Pool (Spec 003) covers the gap, recording `solidarityDebtShares` on the member's position.
- **Clarified two-phase obligation model:** Pre-selection, the member's obligation is to contribute `D` per round — enforced by the Solidarity Pool covering any shortfall and flagging the round. Post-selection, the locked payout mechanically covers all remaining rounds — no active deposits required from the selected member.
- **US-006 formation check updated:** circle kickoff now includes a Solidarity Pool threshold check (Spec 003 US-006) for any pool-dependent members in the forming circle.
- **Updated AC-001-4:** `circleAllocation` is locked either from the member's own `sharesBalance` (self-funded path) or from a combination of own shares and Solidarity Pool advance (pool-backstopped path).

**v0.3 (February 2026):**
- **Closed OQ-004:** Contributions are fixed per circle (uniform across members). Circle matching is driven by two member-declared parameters: `circleAllocation` (portion of savings balance, as % or nominal $) and `circleDuration` (a number + unit input: days / weeks / months / years). `circleAllocation` = pool size = payout. `depositPerRound = circleAllocation / circleSize` is derived. See updated US-001 and Overview.
- **Replaced `preferredFrequency` with `circleDuration` throughout.** Members care about how long their allocation is locked, not the cadence of internal accounting rounds. `roundLength = circleDuration / circleSize` is an internal protocol parameter, not user-facing.
- **Removed AC-003-3, AC-003-4, AC-003-5 (pause mechanics).** A member's `circleAllocation` is locked at entry and the principal lock (Spec 001 AC-004-2) makes `sharesBalance < circleObligationShares` structurally impossible. Pauses cannot occur.
- **Removed US-006 (grace period for paused members).** Void — the failure mode it defended against cannot happen.
- **Closed OQ-005:** Void. Pauses do not exist; buffer reserve coverage of paused contributions is not needed.
- **Updated OQ-003:** Void. The buffer reserve's "cover paused contributions" responsibility is removed. Yield buffer mechanics in Spec 004 stand independently for yield smoothing purposes only.
- **Added US-006 · Circle Formation.** The circle kickoff is a protocol-side algorithm that maximises `circleSize` from the matching queue subject to a yield-quality threshold (>= X% of positions must beat solo saving at current APY). `circleSize` and `roundLength` are both resolved at kickoff — neither is pre-declared by members.
- **Reframed and closed OQ-001:** `circleSize` is not a fixed protocol constant — it emerges from the kickoff algorithm per circle. Remaining open sub-question: valid `circleDuration` range (min/max).
- **Updated AC-001-2, AC-001-3, AC-001-7:** Member declares **intent** (not a commitment to a specific circle). `circleDuration` replaces `preferredFrequency`. Queue and kickoff mechanics expanded.

**v0.2 (February 2026):**
- Payout mechanic updated: the selected member receives **shares** (not USDC) converted from the pool USDC at the current share price. Their `circleObligationShares` increases by the same number of shares.
- Yield leverage premium formula clarified: premium = `convertToAssets(payoutShares)` at time of withdrawal minus `poolUsdc` at time of selection — this is the yield earned on the payout, automatic via share price.
- OQ-002 (yield leverage premium formula) partially resolved — see updated US-002.
- OQ-003 (buffer reserve mechanism) resolved — buffer holds shares, covered in Spec 004 v0.2 AC-004-2.
- Quota window (EARLY/MIDDLE/LATE) design from `cre-manding-circle` incorporated into US-004 as the preferred preference expression model.

---

## Overview

The Savings Circle is the ROSCA mechanic built on top of the Savings Account. It is an optional feature that a member activates when they are ready.

A member joins by declaring **intent**: their **`circleAllocation`** (a portion of their savings balance — expressible as a percentage or a nominal dollar amount) and their **`circleDuration`** (a free-form input: a number and a unit — days, weeks, months, or years). This is an intent, not a commitment to a circle of known size. The protocol queues the intent and forms a circle when the conditions are right.

Each circle has:
- A fixed **`circleAllocation`** — the same for every member; equals the pool size and the payout each selected member receives
- A fixed **`circleDuration`** — the declared lock duration, shared by all members in the circle
- A **`circleSize`** (number of members) — resolved by the kickoff algorithm at formation time, not pre-declared
- A derived **`roundLength`** = `circleDuration / circleSize` — the internal interval between rounds; resolved at kickoff
- A derived **`depositPerRound`** = `circleAllocation / circleSize` — uniform across members; shown for reference
- A **selection mechanism** (verifiable on-chain randomness by default)

The protocol continuously evaluates queued intents and forms circles using a kickoff algorithm (see US-006). At scale, the protocol proactively suggests `circleAllocation` values to members based on their savings balance and the current distribution of queued intents.

Each round, one member is selected to receive the full pool payout. That payout is deposited directly into their Savings Account — not into their withdrawable wallet. It compounds immediately at the full pool size. The payout principal becomes the selected member's circle obligation, automatically repaid through their ongoing savings balance over subsequent rounds.

---

## Problem Statement

The compounding advantage of a lump sum is structurally inaccessible to people saving small amounts. A member who allocates $2,000 to a 10-member circle over 10 months locks $2,000 and the protocol accounts for $200 per round (`$2,000 / 10`). The member selected in round one earns yield on $2,000 from that moment. The member selected in round ten earns yield on $200 for nine months, then $2,000 for one month. The yield leverage premium — the structural advantage previously accessible only to the wealthy — is distributed by rotation.

The single failure mode of traditional ROSCAs (the organiser who can abscond, or the early-payout member who stops contributing) is eliminated by structural enforcement: the principal lock on the Savings Account means there is no unsecured obligation.

---

## User Stories

### US-001 · Join a Circle
**As a** member with an eligible Savings Account balance,
**I want to** activate savings circle participation,
**So that** I can access the compounding advantage of a lump-sum payout.

**Acceptance Criteria:**
- AC-001-1: A member can activate circle participation from their Savings Account dashboard with one action
- AC-001-2: At enrolment the member declares intent: `circleAllocation` (a portion of their savings balance, expressed as % or nominal $) and `circleDuration` (a number + unit input: days / weeks / months / years, e.g. "6 months" or "45 days"). This is an intent — `circleSize` and `roundLength` are unknown until the circle forms. The protocol may suggest a `circleAllocation` value based on the member's balance and current demand distribution.
- AC-001-3: At intent declaration, the member is shown: `circleAllocation` (= pool size = payout they will receive when selected), `circleDuration` (how long their allocation will be locked), and an estimated `depositPerRound` range based on typical circle sizes at that allocation tier. Final `circleSize`, `roundLength`, and `depositPerRound` are confirmed only when the circle forms.
- AC-001-4: Joining requires no additional deposit. Once the circle forms, `circleAllocation` is locked through one of two paths: (a) **self-funded** — carved entirely from the member's own `sharesBalance`; (b) **pool-backstopped** — the member's own shares plus a Solidarity Pool advance cover `circleAllocation` in full, with the advance recorded as `solidarityDebtShares` on the member's position (see Spec 003 US-003).
- AC-001-5: A member may only be in one circle at a time per savings account.
- AC-001-6: At circle formation (not intent declaration), the protocol evaluates the member's entry path: (a) **self-funded** — `yieldRouter.convertToAssets(sharesBalance) >= circleAllocation`; (b) **pool-backstopped** — member's balance is below `circleAllocation` but the Solidarity Pool holds sufficient undeployed capital to cover the gap (Spec 003 AC-003-1). If neither condition is met, the member remains queued. The intent declaration itself requires only that the member has a positive savings balance — no balance floor is enforced at declaration time.
- AC-001-7: After declaring intent, the member is placed in the queue for their `(circleAllocation, circleDuration)` pair. They are notified when a circle forms (see US-006) and may withdraw their intent at any time before formation without penalty.
- AC-001-8: If the protocol finds a better match slightly outside the member's declared parameters, it presents the suggestion with a clear explanation of the yield improvement — the member can accept or decline.

### US-002 · Receive Pool Payout
**As a** member selected in a given round,
**I want to** receive the full pool payout into my savings position,
**So that** I immediately begin earning yield on the larger amount.

**Acceptance Criteria:**
- AC-002-1: At selection, the circle calls `SavingsAccount.creditShares(shieldedId, payoutShares)` where `payoutShares = yieldRouter.convertToShares(poolUsdc)` — the pool USDC is converted to shares at the current share price and credited to the selected member's `sharesBalance`
- AC-002-2: The credited shares immediately earn yield via share price appreciation — no separate `creditYield()` call is needed
- AC-002-3: `circleObligationShares` is set equal to `payoutShares` — the selected member cannot redeem these shares until the obligation is settled over subsequent rounds
- AC-002-4: The yield leverage premium is the **difference in USDC value** the selected member extracts compared to a member who never received the payout: `premium = convertToAssets(payoutShares_at_withdrawal) - poolUsdc_at_selection`. This grows automatically as share price rises.
- AC-002-5: The member receives a clear notification showing: pool USDC equivalent at time of selection, shares credited, new total `sharesBalance`, USDC-equivalent obligation, and estimated premium (projected at current APY)
- AC-002-6: A member can only receive the payout once per full rotation cycle

### US-003 · Automatic Obligation Settlement
**As a** member who has received the payout,
**I want** my circle obligation to be automatically satisfied over subsequent rounds,
**So that** I do not need to take manual action to honour my commitment after selection.

**Acceptance Criteria:**
- AC-003-1: At each round boundary, the circle reduces the selected member's `circleObligationShares` by `roundObligationShares = payoutShares / remainingRounds` — this is the per-round settlement amount
- AC-003-2: Settlement is triggered automatically when `executeRound()` is called (permissionless) — no manual transaction from the member
- AC-003-3: **Post-selection, no active deposits are required from the selected member.** The locked payout (`circleObligationShares`) mechanically covers all remaining rounds — the obligation decreases each round as shares are released to the pool. This is a structural property of the payout lock, not a behavioural requirement on the member.
- AC-003-4: **Pre-selection**, the member's obligation is to contribute `D` per round from their available balance. If they cannot cover `D` in a given round, the Solidarity Pool covers the shortfall automatically (Spec 003 US-004) — the member remains in the draw and the circle proceeds unaffected.

### US-004 · Fair Selection
**As a** member,
**I want** selection to be provably fair and unpurchasable by capital,
**So that** the structural equality of the mechanism is maintained.

**Acceptance Criteria:**
- AC-004-1: Selection uses Chainlink VRF v2.5 (via the `DrawConsumer` contract from `cre-manding-circle`) — Fisher-Yates shuffle on the VRF random word produces a verifiable participant ordering
- AC-004-2: The full draw order is stored on-chain via `DrawConsumer.getDrawOrder(requestId)` — any member can verify their selection outcome
- AC-004-3: No member can purchase earlier selection through capital bids — the only preference mechanism is the quota window cohort (EARLY / MIDDLE / LATE), chosen at enrolment
- AC-004-4: **Quota window cohorts (adopted from `cre-manding-circle`):** at enrolment, members choose which third of the cycle they prefer to be eligible (EARLY, MIDDLE, or LATE). Slots in each cohort are capped equally. Selection within each cohort is VRF-random. This gives preference agency without allowing capital to purchase timing — a member with $1 and a member with $10,000 have equal selection probability within the same cohort.
- AC-004-5: Every member receives the payout exactly once per full rotation cycle, across all three cohort windows

### US-005 · Circle Completion
**As a** member completing a full rotation cycle,
**I want** the circle to close cleanly,
**So that** I receive my remaining balance and can choose whether to join a new circle.

**Acceptance Criteria:**
- AC-005-1: At the end of a full cycle, all obligations are settled and all balances reconciled
- AC-005-2: Each member retains their principal (net of circle obligations already settled) plus all yield earned during participation
- AC-005-3: After completion, a member's `circleObligation` is reset to zero
- AC-005-4: The member is offered the option to immediately join a new circle or return to standalone savings account mode
- AC-005-5: A full cycle audit trail (selection events, payout amounts, yield earned by each member) is available on-chain for member verification

### US-006 · Circle Formation
**As a** member with a queued intent,
**I want** the protocol to form the best possible circle from available demand,
**So that** my yield advantage is maximised within my declared parameters.

**Acceptance Criteria:**
- AC-006-1: The protocol continuously evaluates queued intents grouped by `(circleAllocation, circleDuration)`. When a group reaches a candidate size, the kickoff algorithm runs. For any pool-backstopped members in the candidate group, the algorithm also checks the Solidarity Pool threshold (Spec 003 AC-006-1): the pool must hold at least `(N-1) × D` in undeployed capital per pool-dependent member. If the threshold is not met, the candidate N is reduced until it is, or the circle does not form.
- AC-006-2: The kickoff algorithm evaluates candidate `circleSize` values N from the current queue depth down to a minimum viable N. For each N it computes `roundLength = circleDuration / N`, fetches the current APY from the YieldRouter, and calculates the yield advantage for every position 1..N relative to solo saving.
- AC-006-3: A circle is viable if the share of positions that beat solo saving meets or exceeds the **formation threshold** (a governance-configurable parameter, e.g. 70%). The algorithm selects the largest viable N — more members means more total yield generated and a longer hold time for early positions.
- AC-006-4: Once the optimal N is selected, the circle is closed to new members, each queued member's `circleAllocation` is locked as `circleObligationShares`, and the circle starts at the resolved `roundLength`.
- AC-006-5: Members are notified of the final circle parameters (`circleSize`, `roundLength`, `depositPerRound`) before their allocation is locked. They have a short confirmation window (governance-configurable) to withdraw their intent if the resolved parameters are unacceptable.
- AC-006-6: If no viable N exists in the current queue (demand is too thin), the protocol may propose adjusted parameters to queued members — e.g. a slightly shorter or longer `circleDuration`, or a different `circleAllocation` tier — with a clear explanation of the expected yield improvement. Accepting the proposal re-queues the member under the new parameters.
- AC-006-7: At scale, the protocol proactively suggests `circleAllocation` values to members when they activate savings circle participation, based on the member's savings balance and the current depth of queued intents. Suggestions aim to minimise queue time while maximising yield advantage.

---

## Out of Scope for This Spec

- Vouching mechanics (covered in Spec 003 — Solidarity Market)
- Yield engine internals (covered in Spec 004 — Yield Engine)
- Circle member communication features (not in scope for v1; off-chain coordination is out of scope)
- Larger circle tiers requiring vouching (cross-reference to Spec 003)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | ~~Fixed circleSize?~~ **Resolved in v0.3:** `circleSize` is not fixed — it is resolved per-circle by the kickoff algorithm (US-006) to the largest N that satisfies the formation threshold. Open sub-question: what are the valid bounds for `circleDuration` (minimum and maximum a member may declare)? | Product | **Partially closed** |
| OQ-002 | ~~How is the yield leverage premium calculated?~~ **Partially resolved in AC-002-4:** `premium = convertToAssets(payoutShares_at_withdrawal) - poolUsdc_at_selection`. This is exact and member-verifiable from on-chain state. The open sub-question: do we show a *projected* premium at selection time, and if so, at what APY assumption? | Protocol Economist | **Partially closed** |
| OQ-003 | ~~Buffer reserve mechanism?~~ **Void as of v0.3:** The buffer reserve's role in covering paused member contributions is removed — pauses are structurally impossible. Yield buffer in Spec 004 remains for yield smoothing only; its design is out of scope for this spec. | Protocol Architect | **Closed** |
| OQ-004 | ~~Fixed or variable contributions per member?~~ **Resolved in v0.3:** Fixed per circle. Each member declares `circleAllocation` (= pool size = payout target); `depositPerRound = circleAllocation / circleSize` is uniform across all members. Variable contributions are unnecessary — tier flexibility is handled by member self-selection at enrolment. | Product | **Closed** |
| OQ-005 | ~~Maximum simultaneous pauses?~~ **Void as of v0.3:** Pauses are structurally impossible. The principal lock enforces `sharesBalance >= circleObligationShares` at all times — a member cannot reduce their balance below their locked obligation. | Protocol Architect | **Closed** |
