# Spec 002 — Savings Circle

**Status:** Draft
**Version:** 0.6
**Date:** March 2026
**Depends on:** Spec 001 (Savings Account), Spec 003 (Safety Net Pool), Spec 004 (Yield Engine)

---

## Changelog

**v0.6 (March 2026):**
- **Installment-first model.** Primary user input is now `depositPerRound` (how much I can put away per period) + `duration` (for how long). `circleAllocation = N × depositPerRound` is derived at kickoff — the member never declares the pool size. The entry framing is: "how much can you put away, and for how long?" not "how much do you want?"
- **Matching queue rekeyed.** Queue groups by `(depositPerRound, duration)` pairs. `circleAllocation` is a derived output of the kickoff algorithm, not a declared input.
- **Added `minDepositPerRound`.** Defaults to `depositPerRound / 2`. If a member pays only `minDepositPerRound` in a given round, the Safety Net Pool covers the gap. Member pays interest on covered portion from that round forward. Can be elected upfront or activated mid-circle (US-007).
- **Removed entry balance requirement.** No `sharesBalance >= circleAllocation` check at intent declaration. A member needs only enough balance to cover one `minDepositPerRound`. The Safety Net Pool is the structural guarantee.
- **Added reallocation mechanic.** If a member cannot pay even `minDepositPerRound`, the protocol reallocates them to a smaller circle they can sustain, or exits them cleanly with contributions returned minus any Safety Net Pool debt. Circle corrects, not punishes (US-008).
- **Obligation formula updated.** `circleObligationShares = convertToShares(remainingRounds × depositPerRound)` set at selection. Reduces by `convertToShares(depositPerRound)` per round.
- **USDC throughout.** Replaced USDS with USDC.

**v0.5 (February 2026):**
- Entry check simplified. Round coverage model simplified. Per-round `solidarity_covered` flags removed.

**v0.3 (February 2026):**
- Replaced `preferredFrequency` with `circleDuration`. Removed pause mechanics. Added US-006 Circle Formation with kickoff algorithm. Closed OQ-004, OQ-005.

---

## Overview

The Savings Circle is the ROSCA mechanic built on top of the Savings Account. It is an optional feature a member activates when ready.

The entry question is not *how much do you want?* — it is *how much can you put away, and for how long?*

A member joins by declaring two things: their **`depositPerRound`** (how much they can contribute per period, as a dollar amount) and their **`duration`** (a number and a unit — days, weeks, months, or years). This is an intent, not a commitment to a circle of known size. The protocol queues the intent and forms a circle when conditions are right.

Each circle has:
- A fixed **`depositPerRound`** — the same for every member; the contribution each member makes per round
- A fixed **`duration`** — the declared lock duration, shared by all members
- A **`circleSize`** (N) — resolved by the kickoff algorithm at formation, not pre-declared
- A derived **`roundLength`** = `duration / N` — the interval between rounds; resolved at kickoff
- A derived **`circleAllocation`** = `N × depositPerRound` — the pool size and payout each selected member receives; shown at formation, never declared
- An optional **`minDepositPerRound`** ≤ `depositPerRound` — the minimum installment guaranteed per round (defaults to `depositPerRound / 2`); activating this triggers Safety Net Pool coverage and interest payment (US-007)
- A **selection mechanism** — verifiable on-chain randomness (Chainlink VRF v2.5)

Each round, one member is selected to receive the full `circleAllocation` payout credited directly to their Savings Account. It compounds immediately at the full pool size. The payout becomes the selected member's circle obligation, settled automatically through ongoing `depositPerRound` contributions over subsequent rounds.

---

## Problem Statement

The compounding advantage of a lump sum is structurally inaccessible to people saving small amounts. But the question was never "how do I get a lump sum?" — it was "how do I make my regular contributions work harder?"

A member who can put away \$100 a month for a year joins a circle with N similarly-committed members. The pool is `100 × N`. Nobody needed to have that amount upfront. The member selected first earns yield on the full pool from that moment. The member selected last earns yield on \$100 for most of the year, then the full pool for one round. The yield leverage premium — the structural advantage previously accessible only to the wealthy — is distributed by rotation.

The structural failure mode of traditional ROSCAs (the organiser, the early-payout member who stops contributing) is eliminated by structural enforcement: the minimum installment is always guaranteed — at least half by the member, at most half by the Safety Net Pool. If a member can no longer sustain even the minimum, the circle corrects and the member is reallocated, not punished.

---

## User Stories

### US-001 · Join a Circle
**As a** member with a savings account,
**I want to** activate savings circle participation,
**So that** I can access the compounding advantage of receiving the pooled installments when selected.

**Acceptance Criteria:**
- AC-001-1: A member can activate circle participation from their Savings Account dashboard with one action
- AC-001-2: At enrolment the member declares intent: `depositPerRound` (how much they can contribute per period, as a dollar amount) and `duration` (a number + unit: days / weeks / months / years, e.g. "12 months"). This is an intent — `circleSize`, `roundLength`, and `circleAllocation` are unknown until the circle forms
- AC-001-3: At intent declaration, the member is shown: their `depositPerRound`, their `duration`, and an estimated `circleAllocation` range based on typical circle sizes at that installment tier (e.g., "You'll receive between \$800 and \$1,500 when selected, depending on circle size"). Final `circleSize`, `roundLength`, and `circleAllocation` are confirmed only at formation
- AC-001-4: Joining requires no large upfront deposit. The member's savings account needs enough balance to cover one `minDepositPerRound`
- AC-001-5: A member may only be in one circle at a time per savings account
- AC-001-6: The protocol checks that the member's savings balance covers at least one `minDepositPerRound` at intent declaration. No floor equal to `circleAllocation` is required
- AC-001-7: After declaring intent, the member is placed in the queue for their `(depositPerRound, duration)` pair. They may withdraw their intent at any time before formation without penalty
- AC-001-8: If the protocol finds a better match slightly outside the member's declared parameters, it presents the suggestion with a clear explanation of the yield improvement — the member can accept or decline
- AC-001-9: At intent declaration, the member may declare a `minDepositPerRound` ≤ `depositPerRound`. If not declared, it defaults to `depositPerRound / 2`

### US-002 · Receive Pool Payout
**As a** member selected in a given round,
**I want to** receive the full pool payout into my savings position,
**So that** I immediately begin earning yield on the larger amount.

**Acceptance Criteria:**
- AC-002-1: At selection, the circle calls `SavingsAccount.creditShares(shieldedId, payoutShares)` where `payoutShares = yieldRouter.convertToShares(circleAllocation)` — `circleAllocation = N × depositPerRound` converted to shares at the current share price and credited to the selected member's `sharesBalance`
- AC-002-2: The credited shares immediately earn yield via share price appreciation — no separate `creditYield()` call is needed
- AC-002-3: If the selected member has `safetyNetDebtShares > 0` (Safety Net Pool coverage outstanding), those shares are settled first — transferred to the Safety Net Pool — before `circleObligationShares` is set (Spec 003 AC-004-2)
- AC-002-4: `circleObligationShares` = `convertToShares(remainingRounds × depositPerRound)`, where `remainingRounds = N − selectionRound`. The selected member cannot redeem these shares until settled through subsequent installments
- AC-002-5: Yield leverage premium: `convertToAssets(payoutShares_at_withdrawal) − circleAllocation_at_selection`. Grows automatically as share price rises
- AC-002-6: Member receives notification: `circleAllocation` at selection, shares credited, Safety Net Pool debt cleared (if any), net `circleObligationShares` locked, new `sharesBalance`, and estimated premium at current APY
- AC-002-7: A member can only receive the payout once per full rotation cycle

### US-003 · Automatic Obligation Settlement
**As a** member who has received the payout,
**I want** my circle obligation to be automatically satisfied over subsequent rounds,
**So that** I do not need to take manual action to honour my commitment.

**Acceptance Criteria:**
- AC-003-1: At each round boundary, `circleObligationShares` is reduced by `convertToShares(depositPerRound)` — one installment's worth per round
- AC-003-2: Settlement is triggered automatically when `executeRound()` is called (permissionless)
- AC-003-3: If the member is using the minimum installment option (US-007), the Safety Net Pool covers the gap. `circleObligationShares` settlement still reduces by the full `convertToShares(depositPerRound)` — the obligation clock does not slow. The pool's contribution is tracked separately as `safetyNetDebtShares`

### US-004 · Fair Selection
**As a** member,
**I want** selection to be provably fair and unpurchasable by capital,
**So that** the structural equality of the mechanism is maintained.

**Acceptance Criteria:**
- AC-004-1: Selection uses Chainlink VRF v2.5 — Fisher-Yates shuffle on the VRF random word produces a verifiable participant ordering
- AC-004-2: The full draw order is stored on-chain — any member can verify their selection outcome
- AC-004-3: No member can purchase earlier selection through capital bids — the only preference mechanism is the quota window cohort (EARLY / MIDDLE / LATE)
- AC-004-4: **Quota window cohorts:** at enrolment, members choose which third of the cycle they prefer (EARLY, MIDDLE, LATE). Slots are capped equally. Selection within each cohort is VRF-random. A member contributing \$10 a month and a member contributing \$1,000 a month have equal selection probability within the same cohort
- AC-004-5: Every member receives the payout exactly once per full rotation cycle

### US-005 · Circle Completion
**As a** member completing a full rotation cycle,
**I want** the circle to close cleanly,
**So that** I receive my remaining balance and can choose whether to join a new circle.

**Acceptance Criteria:**
- AC-005-1: At the end of a full cycle, all obligations are settled and all balances reconciled
- AC-005-2: Each member retains their principal (net of settled circle obligations) plus all yield earned during participation
- AC-005-3: After completion, `circleObligationShares` is reset to zero
- AC-005-4: The member is offered the option to immediately re-declare intent for a new circle or return to standalone savings account mode
- AC-005-5: A full cycle audit trail (selection events, payout amounts, yield per member) is available on-chain

### US-006 · Circle Formation
**As a** member with a queued intent,
**I want** the protocol to form the best possible circle from available demand,
**So that** my yield advantage is maximised within my declared parameters.

**Acceptance Criteria:**
- AC-006-1: The protocol continuously evaluates queued intents grouped by `(depositPerRound, duration)`. When a group reaches a candidate size, the kickoff algorithm runs
- AC-006-2: The kickoff algorithm evaluates candidate `circleSize` values N from queue depth down to a minimum viable N. For each N it computes `roundLength = duration / N`, derives `circleAllocation = N × depositPerRound`, fetches current APY from the YieldRouter, and calculates the yield advantage for every position 1..N relative to solo saving
- AC-006-3: A circle is viable if the share of positions that beat solo saving meets or exceeds the **formation threshold** (governance-configurable, default 70%). The algorithm selects the largest viable N
- AC-006-4: Once the optimal N is selected, the circle is closed to new members and starts at the resolved `roundLength` with derived `circleAllocation = N × depositPerRound`
- AC-006-5: Members are notified of the final parameters (`circleSize`, `roundLength`, `circleAllocation`) before the circle starts. A short confirmation window (governance-configurable) allows withdrawal of intent if the resolved parameters are unacceptable
- AC-006-6: If no viable N exists (demand too thin), the protocol proposes adjusted parameters to queued members with a clear explanation of the expected yield improvement. Accepting re-queues the member under new parameters
- AC-006-7: At scale, the protocol proactively suggests `depositPerRound` values to members at intent declaration, based on their savings balance and current queue depth

### US-007 · Minimum Installment Option
**As a** member who may not be able to pay the full installment every round,
**I want** the option to pay a guaranteed minimum installment,
**So that** I can stay in my circle during a difficult period without the circle failing.

**Acceptance Criteria:**
- AC-007-1: `minDepositPerRound` ≤ `depositPerRound`. Defaults to `depositPerRound / 2` if not declared. Must be ≥ a governance-configurable floor (e.g., \$1)
- AC-007-2: **Electing upfront:** member declares at enrolment they will pay `minDepositPerRound` from round one. The Safety Net Pool covers `depositPerRound − minDepositPerRound` each round and the member pays interest on the covered amount from round one
- AC-007-3: **Activating mid-circle:** member paying full `depositPerRound` can activate the minimum option at any round. Pool covers the gap from that round forward; interest begins from the activation round
- AC-007-4: When the minimum option is active, `safetyNetDebtShares` increases by `convertToShares(depositPerRound − minDepositPerRound)` each covered round. Interest accrues on `safetyNetDebtShares` at the coverage rate (Spec 003 OQ-005), charged from the member's yield earnings before they accrue to the member's position
- AC-007-5: The minimum option can be deactivated at any time by resuming full `depositPerRound` payments. Interest on future rounds stops; existing `safetyNetDebtShares` continue accruing until settled at selection
- AC-007-6: At selection, `safetyNetDebtShares` is settled first from the gross payout before `circleObligationShares` is set (US-002 AC-002-3, Spec 003 AC-004-2)
- AC-007-7: Member position display shows: `depositPerRound`, `minDepositPerRound`, whether minimum option is active, cumulative `safetyNetDebtShares`, accrued interest, and estimated net payout after debt settlement

### US-008 · Reallocation When Member Cannot Pay Minimum
**As a** member who cannot sustain even the minimum installment,
**I want** to be reallocated rather than punished,
**So that** I recover my savings and continue participating at a level I can afford.

**Acceptance Criteria:**
- AC-008-1: If a member cannot pay `minDepositPerRound` in a given round, the protocol surfaces a question: is there a smaller `depositPerRound` (and implied `minDepositPerRound`) the member can sustain?
- AC-008-2: If yes — the protocol initiates reallocation. The member exits the current circle and is re-queued for a circle matching what they can afford. Their paid contributions to date are returned to their savings account, minus any `safetyNetDebtShares` owed to the Safety Net Pool
- AC-008-3: The circle the member is leaving adjusts for the departed member. The protocol seeks a replacement from the queue whose `depositPerRound` and remaining `duration` fit the open position. The Safety Net Pool may temporarily cover the open slot while a replacement is found
- AC-008-4: Remaining circle members experience at most a temporary reduction in `circleAllocation` while the replacement is being matched. Once a replacement joins, `circleAllocation` is restored. Members are notified of the adjustment and its resolution
- AC-008-5: If no — the member cannot commit to any installment right now. The Savings Circle feature turns off. No further installments are owed. Contributions already paid are returned to the savings account minus any Safety Net Pool debt. The circle feature can be reactivated when the member is ready
- AC-008-6: In no scenario does a member permanently lose contributions already made. The design corrects, not punishes

---

## Out of Scope for This Spec

- Safety Net Pool mechanics and coverage interest rate (Spec 003)
- Yield engine internals (Spec 004)
- Circle member communication (not in scope for v1)
- Privacy layer ZK proofs (deferred to v2 per Spec 005)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Valid `duration` bounds: minimum and maximum a member may declare. Minimum prevents degenerate round lengths; maximum prevents unreasonably long locks. To be explored via simulation. | Product | Open |
| OQ-002 | Projected premium display at selection: show a projected premium, and if so, at what APY assumption? | Protocol Economist | Open |
| OQ-003 | Duration bucketing/tolerance: when members declare `duration` in different units that resolve to similar values (e.g. "30 days" vs "1 month"), how does the protocol group them? Options: exact canonical match, ±5% tolerance, predefined tiers. | Protocol Architect | Open |
| OQ-004 | `minDepositPerRound` default: is `depositPerRound / 2` the right default, or governance-configurable fraction? | Product | Open |
| OQ-005 | Coverage interest rate: should interest on covered installments equal current pool APY or a fixed governance-set rate? | Protocol Economist | Open |
