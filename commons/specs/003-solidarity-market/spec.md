# Spec 003 — Solidarity Market

**Status:** Draft
**Version:** 0.1
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 002 (Savings Circle)

---

## Overview

The Solidarity Market is the peer vouching layer of Commons Protocol. It solves the access gap for members whose savings balance is growing but not yet sufficient for meaningful circle participation.

A member with a larger balance can extend a **vouch** to another member. The vouch designates a portion of the voucher's balance as backing for the vouched member's circle participation, effectively allowing them to join a larger circle tier than their own balance would qualify them for.

The vouch is economically real: the vouched portion is locked, cannot be withdrawn while the vouch is active, and earns the voucher a passive income stream — an interest fee paid from the vouched member's yield earnings, plus a share of the payout differential when the vouched member is selected.

This is not charity. It is mutualized solidarity structured as a market.

---

## Problem Statement

Circle tier is determined by savings balance. This structural guarantee is what makes the principal lock work. A member with $300 can participate in circles up to a proportionate pool size; a member with $2,000 can access larger circles.

This creates an access gap: members building their balance from nothing cannot access meaningful yield leverage until they've saved enough. The Solidarity Market closes this gap — and creates a genuinely new form of passive income for those with larger balances.

Two profiles benefit:
- **Vouched members**: access larger circles and greater yield leverage than their balance alone would permit
- **Vouchers**: deploy idle balance capacity as vouching capital, earning interest plus payout share without actively managing anything

---

## User Stories

### US-001 · Extend a Vouch
**As a** member with a larger savings balance,
**I want to** vouch for another member's circle participation,
**So that** I earn passive income while amplifying another member's access.

**Acceptance Criteria:**
- AC-001-1: A member can vouch for another member from the Solidarity Market interface
- AC-001-2: The voucher specifies: the vouched member's address, the vouch amount (a portion of their savings balance), and the circle tier being backed
- AC-001-3: The vouch amount is immediately locked in the voucher's Savings Account — it cannot be withdrawn while the vouch is active
- AC-001-4: A single member cannot vouch more than 80% of their total balance across all active vouches combined (diversification floor)
- AC-001-5: A member can have a maximum of 20 active vouches simultaneously (to prevent concentration risk)
- AC-001-6: The voucher sees a projected income estimate (interest rate + expected payout share) before confirming the vouch

### US-002 · Receive a Vouch
**As a** member with a smaller savings balance,
**I want to** accept a vouch from another member,
**So that** I can join a circle tier larger than my balance alone would permit.

**Acceptance Criteria:**
- AC-002-1: A member can browse available vouches on the Solidarity Market (vouchers who have signalled willingness to vouch)
- AC-002-2: The vouched member sees the vouch terms before accepting: the vouch amount, the interest rate charged on the leveraged amount, and the payout share owed to the voucher upon selection
- AC-002-3: Accepting a vouch is a one-click action; no identity information is exchanged between voucher and vouched member
- AC-002-4: The combined balance (own balance + vouch amount) is used to determine eligible circle tier
- AC-002-5: The vouched member's `circleObligation` is scaled to the combined balance — they must maintain this combined threshold
- AC-002-6: If the vouched member's balance falls below the required threshold, their participation pauses (not terminates), and the vouch obligation also pauses

### US-003 · Vouch Income — Interest
**As a** voucher,
**I want to** earn an ongoing interest fee on my vouched amount,
**So that** my idle capital generates passive income.

**Acceptance Criteria:**
- AC-003-1: The voucher earns a continuous interest rate on the locked vouch amount, paid from the vouched member's yield earnings
- AC-003-2: The interest rate is set at the time the vouch is created and is fixed for the vouch duration (no variable rate that can be gamed)
- AC-003-3: Interest accrues per block and is claimable at any time without closing the vouch
- AC-003-4: The interest payment does not come from the vouched member's principal — it comes only from their yield earnings above the base rate
- AC-003-5: If the vouched member's yield falls below the interest obligation (e.g., yield rates drop), the unpaid interest accrues and is settled from the payout differential when selection occurs

### US-004 · Vouch Income — Payout Share
**As a** voucher,
**I want to** receive a share of the payout differential when the vouched member is selected,
**So that** I earn a meaningful return when my backing creates the most value.

**Acceptance Criteria:**
- AC-004-1: When the vouched member is selected for the pool payout, the voucher automatically receives a proportional share of the yield leverage premium
- AC-004-2: The payout share is calculated as: `vouchAmount / totalCirclePosition * yieldLeveragePremium * agreedSplitRatio`
- AC-004-3: The split ratio is agreed at vouch creation time and is visible to both parties
- AC-004-4: The payout share is transferred automatically to the voucher's Savings Account at the moment of selection
- AC-004-5: The vouched member retains the remaining yield leverage premium after the voucher's share is paid

### US-005 · Vouch Expiry and Renewal
**As a** voucher,
**I want** my vouch to have a defined term,
**So that** my capital is not locked indefinitely.

**Acceptance Criteria:**
- AC-005-1: Every vouch has a defined term aligned to the circle duration (a vouch expires when the associated circle completes)
- AC-005-2: At expiry, the locked vouch amount is automatically returned to the voucher's withdrawable balance
- AC-005-3: A voucher can offer to renew the vouch at the start of a new circle; the vouched member can accept or decline
- AC-005-4: A voucher cannot unilaterally withdraw a vouch mid-circle — the capital is locked for the circle duration
- AC-005-5: If the vouched member exits a circle early (grace period exhausted), the vouch closes and the locked amount is returned minus any unsettled interest obligations

### US-006 · Discover Vouching Opportunities
**As a** member with vouching capacity,
**I want to** find members who would benefit from a vouch,
**So that** I can deploy my capital productively.

**Acceptance Criteria:**
- AC-006-1: The Solidarity Market shows a list of members seeking vouches, with: their current balance, the vouch amount needed to reach the next circle tier, their savings history within the protocol (duration, consistency of deposits — no identity information)
- AC-006-2: Members can opt in or out of appearing in the Solidarity Market discovery list
- AC-006-3: No real-world identity information is ever shown — only on-chain savings behaviour
- AC-006-4: A voucher can filter opportunities by required vouch amount, circle tier, and savings history length
- AC-006-5: The discovery list is anonymised — vouched members are shown by pseudonymous protocol identifier only

---

## Out of Scope for This Spec

- Secondary market for vouch positions (not in v1; would need careful anti-speculation design)
- Community vouching pools (multiple vouchers co-vouching for a single member) — future feature
- Automated vouching strategies (bots that algorithmically deploy vouching capital) — allowed but not a protocol-provided feature

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | What is the interest rate structure for vouching? Fixed at protocol governance level, or set by market dynamics (voucher and vouched member negotiate)? Market dynamics maximise efficiency; governance floor prevents exploitation. | Protocol Economist | Open |
| OQ-002 | What is the default split ratio for payout share (voucher vs. vouched member)? 20/80 suggested as a starting point. | Product | Open |
| OQ-003 | How does the privacy layer affect vouch discovery? If balances are shielded, how does the voucher verify the vouched member's balance and savings history without revealing it publicly? ZK proof of balance range may be required. | Protocol Architect | Open |
| OQ-004 | What happens if the voucher's own balance falls below the diversification floor due to their own yield fluctuations? Does the vouch auto-reduce or does the voucher need to add capital? | Smart Contract Lead | Open |
