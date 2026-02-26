# Spec 002 — Savings Circle

**Status:** Draft
**Version:** 0.2
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 004 (Yield Engine)

---

## Changelog

**v0.2 (February 2026):**
- Payout mechanic updated: the selected member receives **shares** (not USDC) converted from the pool USDC at the current share price. Their `circleObligationShares` increases by the same number of shares.
- Yield leverage premium formula clarified: premium = `convertToAssets(payoutShares)` at time of withdrawal minus `poolUsdc` at time of selection — this is the yield earned on the payout, automatic via share price.
- OQ-002 (yield leverage premium formula) partially resolved — see updated US-002.
- OQ-003 (buffer reserve mechanism) resolved — buffer holds shares, covered in Spec 004 v0.2 AC-004-2.
- Quota window (EARLY/MIDDLE/LATE) design from `cre-manding-circle` incorporated into US-004 as the preferred preference expression model.

---

## Overview

The Savings Circle is the ROSCA mechanic built on top of the Savings Account. It is an optional feature that a member activates when they are ready. The protocol places them in a circle appropriate to their balance size.

Each circle has:
- A fixed **pool size** (sum of all member contributions per round)
- A fixed **member count** and **contribution amount per member**
- A defined **rotation schedule** (e.g., monthly rounds)
- A **selection mechanism** (verifiable on-chain randomness by default)

Each round, one member is selected to receive the full pool payout. That payout is deposited directly into their Savings Account — not into their withdrawable wallet. It compounds immediately at the full pool size. The payout principal becomes the selected member's circle obligation, automatically repaid through their ongoing savings balance over subsequent rounds.

---

## Problem Statement

The compounding advantage of a lump sum is structurally inaccessible to people saving small amounts. A 10-member circle with $200/month contributions creates a $2,000 pool. The member selected in round one earns yield on $2,000 from that moment. The member selected in round ten earns yield on $200 for nine months, then $2,000 for one month. The yield leverage premium — the structural advantage previously accessible only to the wealthy — is distributed by rotation.

The single failure mode of traditional ROSCAs (the organiser who can abscond, or the early-payout member who stops contributing) is eliminated by structural enforcement: the principal lock on the Savings Account means there is no unsecured obligation.

---

## User Stories

### US-001 · Join a Circle
**As a** member with an eligible Savings Account balance,
**I want to** activate savings circle participation,
**So that** I can access the compounding advantage of a lump-sum payout.

**Acceptance Criteria:**
- AC-001-1: A member can activate circle participation from their Savings Account dashboard with one action
- AC-001-2: The protocol automatically matches the member to a circle sized for their balance (no manual circle selection required — the protocol handles grouping)
- AC-001-3: The member is shown the circle parameters before joining: pool size, number of members, contribution amount, round frequency, and selection method
- AC-001-4: Joining requires no additional deposit beyond the existing savings balance
- AC-001-5: A member may only be in one circle at a time per savings account

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
**So that** I do not need to take manual action to honour my commitment.

**Acceptance Criteria:**
- AC-003-1: At each round boundary, the circle reduces the selected member's `circleObligationShares` by `roundObligationShares = payoutShares / remainingRounds` — this is the per-round settlement amount
- AC-003-2: Settlement is triggered automatically when `executeRound()` is called (permissionless) — no manual transaction from the member
- AC-003-3: If `sharesBalance < circleObligationShares` (detectable when a member's balance drops and share price alone won't recover it), participation is `PAUSED` — not terminated or slashed
- AC-003-4: Paused participation resumes automatically once `sharesBalance >= circleObligationShares` is restored
- AC-003-5: A paused member's position — including their accumulated share price appreciation — is fully preserved during the pause period

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

### US-006 · Grace Period for Paused Members
**As a** member whose participation is paused due to insufficient balance,
**I want** a grace period before my position is fully suspended,
**So that** temporary shortfalls do not result in permanent exclusion.

**Acceptance Criteria:**
- AC-006-1: A member entering a paused state receives a grace period of one full round before their slot is reassigned
- AC-006-2: During the grace period, the circle continues normally; the paused member's contribution slot is temporarily covered by the circle's buffer reserve (see Spec 004 for yield reserve mechanics)
- AC-006-3: If the member restores their balance within the grace period, participation resumes without penalty
- AC-006-4: If the balance is not restored after the grace period, the member's slot is released and they exit the circle with their current balance minus any outstanding obligations
- AC-006-5: The grace period duration is configurable by protocol governance (default: 1 round)

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
| OQ-001 | What is the minimum and maximum circle size (number of members)? The `cre-manding-circle` uses 3-member circles in tests; 9–12 suggested for production. | Product | Open |
| OQ-002 | ~~How is the yield leverage premium calculated?~~ **Partially resolved in AC-002-4:** `premium = convertToAssets(payoutShares_at_withdrawal) - poolUsdc_at_selection`. This is exact and member-verifiable from on-chain state. The open sub-question: do we show a *projected* premium at selection time, and if so, at what APY assumption? | Protocol Economist | **Partially closed** |
| OQ-003 | ~~Buffer reserve mechanism?~~ **Resolved in Spec 004 v0.2 AC-004-2:** Buffer holds YieldRouter shares, earns yield passively. Covered contributions are paid by redeeming buffer shares at current share price. | Protocol Architect | **Closed** |
| OQ-004 | Do circles have fixed or variable contribution amounts per member? Fixed is simpler and matches the `cre-manding-circle` implementation. Variable (balances differ per member) adds complexity but allows better tier matching. Recommend fixed for v1. | Product | Open |
| OQ-005 | Maximum simultaneous pauses before circle restructures? The buffer reserve covers one paused member per round cleanly. Two or more paused members simultaneously require a larger buffer or a restructuring mechanism. Needs protocol economist input. | Protocol Architect | Open |
