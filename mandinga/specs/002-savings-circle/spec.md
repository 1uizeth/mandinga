# Spec 002 — Savings Circle

**Status:** Draft
**Version:** 0.1
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 004 (Yield Engine)

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
- AC-002-1: The full pool amount is transferred into the selected member's Savings Account at the start of the round
- AC-002-2: The deposited amount is immediately yield-bearing at the full pool size
- AC-002-3: The payout principal is set as the member's `circleObligation` — it cannot be withdrawn
- AC-002-4: Only the yield earned on the payout principal (above what the member would have earned on their original balance) is the member's to keep as a yield leverage premium
- AC-002-5: The member receives a clear notification of selection and a breakdown: pool received, new balance, obligation created, estimated yield leverage premium
- AC-002-6: A member can only receive the payout once per full rotation cycle

### US-003 · Automatic Obligation Settlement
**As a** member who has received the payout,
**I want** my circle obligation to be automatically satisfied over subsequent rounds,
**So that** I do not need to take manual action to honour my commitment.

**Acceptance Criteria:**
- AC-003-1: The obligation is automatically settled from the member's savings balance over the remaining rounds of the circle
- AC-003-2: Settlement is triggered automatically at each round boundary — no manual transaction required
- AC-003-3: If the member's balance falls below the obligation threshold, their participation is `PAUSED` (not terminated or slashed)
- AC-003-4: Paused participation can be resumed when the member's balance is restored to the required threshold
- AC-003-5: A paused member's position is preserved — they do not lose their rotation slot or their previously earned yield

### US-004 · Fair Selection
**As a** member,
**I want** selection to be provably fair and unpurchasable by capital,
**So that** the structural equality of the mechanism is maintained.

**Acceptance Criteria:**
- AC-004-1: Default selection uses Chainlink VRF or equivalent verifiable on-chain randomness
- AC-004-2: The selection result is publicly verifiable (the randomness seed and derivation are on-chain)
- AC-004-3: No member can purchase earlier selection through capital bids (no auction mechanic)
- AC-004-4: The protocol may offer preference expression (members can signal preferred round, not guaranteed) — but expressed preferences cannot override random selection unless all members have expressed a preference and a conflict-free ordering exists
- AC-004-5: Selection order over a full cycle ensures every member receives the payout exactly once

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
| OQ-001 | What is the minimum and maximum circle size (number of members)? 5–20 suggested, but data on optimal ROSCA size is worth reviewing. | Product | Open |
| OQ-002 | How is the yield leverage premium calculated exactly? We need a formula that is simple enough for a member to verify. | Protocol Economist | Open |
| OQ-003 | What is the buffer reserve mechanism for covering paused member contributions during the grace period? Is this funded from yield, from the protocol fee, or from a dedicated reserve? | Protocol Architect | Open |
| OQ-004 | Do circles have fixed or variable contribution amounts? Fixed is simpler; variable allows circles to be sized to the full range of member balances. | Product | Open |
| OQ-005 | What happens if more than one member is paused simultaneously? Is there a maximum pause tolerance before the circle restructures? | Protocol Architect | Open |
