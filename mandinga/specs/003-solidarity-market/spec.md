# Spec 003 — Solidarity Market

**Status:** Draft
**Version:** 0.2
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 002 (Savings Circle)

---

## Changelog

**v0.2 (February 2026):**
- Vouch amounts are stored as **shares** (`vouchShares`), not USDC. This is consistent with how SavingsAccount stores all positions.
- The 80% diversification floor is checked in shares: `totalVouchedShares / sharesBalance <= 0.8`.
- OQ-004 (voucher balance falls below diversification floor due to yield) is partially resolved: yield only increases `sharesBalance`, so the 80% check only tightens if the voucher withdraws capital — not from yield fluctuations.
- Interest accrual: specified as a **USDC-equivalent rate** applied to `convertToAssets(vouchShares)` — avoids the complexity of a shares-denominated interest rate that changes with share price.
- Payout share: `yieldLeveragePremium` is now precisely defined (from Spec 002 OQ-002 resolution): `convertToAssets(payoutShares_now) - poolUsdc_at_selection`.

---

## Overview

The Solidarity Market is the peer vouching layer of Mandinga Protocol. It solves the access gap for members whose savings balance is growing but not yet sufficient for meaningful circle participation.

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
- AC-001-2: The voucher specifies: the vouched member's shielded ID, the vouch USDC amount (converted to `vouchShares = convertToShares(vouchUsdc)`), and the circle tier being backed
- AC-001-3: `vouchShares` is added to the voucher's `circleObligationShares` — these shares are locked and cannot be withdrawn while the vouch is active
- AC-001-4: The diversification floor is enforced in shares: `(totalActiveVouchedShares + vouchShares) / sharesBalance <= 0.8`. Since yield only increases `sharesBalance`, this ratio can only worsen if the voucher *withdraws* capital — not from yield appreciation.
- AC-001-5: A member can have a maximum of 20 active vouches simultaneously
- AC-001-6: The voucher sees a projected income estimate (annualised interest on `convertToAssets(vouchShares)` + expected payout share at current APY) before confirming

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
- AC-003-1: The voucher earns interest expressed as an annualised rate applied to the **USDC-equivalent value** of the vouch: `interestPerSecond = convertToAssets(vouchShares) * interestRateBps / (10000 * 365 days)`. This is recalculated each accrual using the current share price — as the share price rises, so does the interest owed (since the locked capital is worth more).
- AC-003-2: The interest rate (in basis points per year) is fixed at vouch creation time. The USDC-equivalent interest amount will vary with share price, but the rate is locked.
- AC-003-3: Interest accrues per second (stored as `pendingInterestUsdc`) and is claimable at any time without closing the vouch
- AC-003-4: Interest is paid by transferring shares from the vouched member's `sharesBalance` to the voucher's `sharesBalance` (equivalent USDC value). It comes from yield appreciation, not from principal shares.
- AC-003-5: If the vouched member's yield appreciation is insufficient to cover accrued interest (e.g., yield rates collapse), unpaid interest accumulates and is settled from the payout differential shares when the vouched member is selected

### US-004 · Vouch Income — Payout Share
**As a** voucher,
**I want to** receive a share of the payout differential when the vouched member is selected,
**So that** I earn a meaningful return when my backing creates the most value.

**Acceptance Criteria:**
- AC-004-1: When the vouched member is selected, the voucher automatically receives a share of the yield leverage premium — the premium is `convertToAssets(payoutShares_now) - poolUsdc_at_selection` (see Spec 002 AC-002-4)
- AC-004-2: Payout share in USDC-equivalent = `(convertToAssets(vouchShares) / convertToAssets(totalPositionShares)) * yieldLeveragePremium * agreedSplitRatio`; the corresponding number of shares is transferred from vouched member to voucher
- AC-004-3: The split ratio (`agreedSplitRatio`) is set at vouch creation time and is immutable for the vouch duration
- AC-004-4: Payout share is distributed as a share transfer at the moment the `onMemberSelected` callback fires — no separate claim transaction required
- AC-004-5: The vouched member retains `(1 - agreedSplitRatio)` of the yield leverage premium in shares

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
| OQ-001 | What is the interest rate structure for vouching? Fixed at protocol governance level, or negotiated between voucher and vouched member? Market dynamics maximise efficiency; a governance floor prevents exploitation of vulnerable members. | Protocol Economist | Open |
| OQ-002 | What is the default split ratio for payout share (voucher vs. vouched member)? 20/80 suggested as a starting point. | Product | Open |
| OQ-003 | How does the privacy layer affect vouch discovery? If `sharesBalance` is shielded, how does the voucher verify the vouched member's savings history without revealing it publicly? ZK proof of shares-in-range may be required. | Protocol Architect | Open |
| OQ-004 | ~~What happens if the voucher's balance falls below the diversification floor due to yield fluctuations?~~ **Partially resolved:** With share-based accounting, yield only *increases* `sharesBalance`. The 80% diversification floor can only be violated if the voucher *withdraws* capital. If they attempt a withdrawal that would push active vouches above 80% of remaining shares, the withdrawal is blocked with `VouchDiversificationFloorViolation`. | Smart Contract Lead | **Partially closed** |
| OQ-005 | Interest in shares vs. USDC: AC-003-1 specifies interest is computed on the USDC-equivalent of the vouch and paid as a shares transfer. This means a rising share price increases the USDC interest owed each period. Is this the right incentive design, or should interest be a fixed shares-per-second rate? Fixed shares = voucher gets the same nominal interest regardless of price appreciation; USDC-equivalent = voucher's interest scales with the value they're backing. | Protocol Economist | Open |
