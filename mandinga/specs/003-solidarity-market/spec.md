# Spec 003 — Solidarity Pool

**Status:** Draft
**Version:** 0.3
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 002 (Savings Circle)

---

## Changelog

**v0.3 (February 2026):**
- **Full redesign.** The bilateral peer vouching model (Spec 003 v0.2) is replaced entirely by the Solidarity Pool — a shared mutual liquidity buffer.
- **Core insight driving the redesign:** the bilateral model required a voucher to research and trust a specific member, creating friction that prevents the mechanism from scaling. More fundamentally: if a voucher already has the full `circleAllocation` amount, they should join the circle themselves — there is no marginal incentive to vouch for a stranger when direct participation yields the same return. The pool model eliminates this contradiction.
- **The real ROSCA value proposition is credit access** — enabling members to receive a lump sum before they have fully contributed it. The pool enables this by backstopping entry gaps and mid-circle missed rounds, recovering all advances from the payout at selection.
- **Removed:** bilateral vouch relationships, negotiated interest rates, payout share splits, member discovery UI, vouch expiry/renewal, diversification floor per voucher, 20-vouch cap.
- **Added:** pool deposit/withdraw mechanics, entry backstop (covers entry gap to `circleAllocation`), round coverage (covers missed `D` mid-circle), `solidarityDebtShares` tracking per member, atomic debt settlement at selection, pool threshold as circle formation prerequisite.
- **Return model simplified:** Solidarity Pool depositors earn sUSDS yield on deposited capital — the same as a standalone Savings Account. No payout share, no negotiated premium. The pool earns yield while it waits; that is the full return.
- **Recovery guarantee:** every advance is unconditionally recovered from the covered member's payout at selection. Payout = `N × D`; maximum possible debt = `(N-1) × D`; minimum net payout = `D`. The pool cannot lose principal, only timing exposure.

**v0.2 (February 2026):**
- [archived — bilateral peer vouching model]

---

## Overview

The Solidarity Pool is the mutual liquidity layer of Mandinga Protocol. It is a shared pool funded voluntarily by members with idle savings capacity. Its capital enables two things simultaneously: it earns yield passively (same as any savings account), and it backstops circle participation for members who could not otherwise access circles.

The pool serves two functions that share one recovery mechanism:

1. **Entry backstop** — a member whose savings balance is below `circleAllocation` can join a circle if the pool covers the gap. The shortfall becomes `solidarityDebtShares` on the member's position.
2. **Round coverage** — if a member misses a round contribution `D` mid-circle, the pool covers that round automatically. The round is flagged on-chain. The covered amount is added to `solidarityDebtShares`. The member stays in the draw.

**Recovery:** at selection, the payout first clears `solidarityDebtShares` before locking the remainder as `circleObligationShares`. The math guarantees this always works:

```
payout          = N × D
maximum debt    = (N-1) × D  [full-defaulter selected at last round]
minimum net     = D           [always positive]
```

The pool's advance is always fully recovered at selection. Depositors bear timing exposure only — never principal risk.

**Return for depositors:** sUSDS yield on deposited capital. The protocol does not track which depositor's capital funded which advance — the pool is anonymous and fungible. Depositors cannot earn more by enabling an early-position winner; they earn the same yield regardless of how their capital is deployed. The value proposition is: idle capital works, earns yield, and enables a circle to exist that would not otherwise form.

---

## Problem Statement

Spec 002 v0.2 required `sharesBalance >= circleAllocation` at circle entry. A member needed to already have the full pool amount before they could join. This structurally excluded the primary target user: someone building savings from nothing who wants access to a lump sum larger than their current balance.

Two access gaps exist without the Solidarity Pool:

1. **Entry gap** — the member's balance is below `circleAllocation`. They cannot join regardless of their saving behaviour or commitment.
2. **Continuity gap** — a participating member faces a short-term shortfall on a round contribution. Without coverage, the circle is disrupted for all other members.

The Solidarity Pool closes both gaps. Circle entry becomes a function of commitment capacity (ability to sustain ongoing `D` contributions over time), not existing capital. Circle continuity is maintained even when individual members face temporary shortfalls.

---

## User Stories

### US-001 · Deposit into Solidarity Pool
**As a** member with idle savings capacity,
**I want to** deposit capital into the Solidarity Pool,
**So that** my idle capital earns yield while enabling others to join savings circles.

**Acceptance Criteria:**
- AC-001-1: A member can deposit any USDS amount (≥ $1 minimum) into the Solidarity Pool from their Savings Account dashboard
- AC-001-2: Deposited capital is routed to the YieldRouter immediately — the pool holds YieldRouter shares, not USDS. Yield accrues automatically via share price appreciation, identical to a standalone Savings Account.
- AC-001-3: The depositor's pool position is shown as: USDS-equivalent deposited, current USDS-equivalent value (with accrued yield), percentage share of the total pool, and current amount deployed in active advances
- AC-001-4: Pool deposits are entirely separate from the member's Savings Account `sharesBalance` — they do not count toward any circle obligation and do not affect the member's own circle eligibility or selection probability
- AC-001-5: Depositing into the Solidarity Pool is voluntary and has no bearing on the member's own circle participation

### US-002 · Withdraw from Solidarity Pool
**As a** Solidarity Pool depositor,
**I want to** withdraw my deposited capital at any time,
**So that** I maintain liquidity over my savings.

**Acceptance Criteria:**
- AC-002-1: A depositor can withdraw their proportional share of undeployed pool capital at any time
- AC-002-2: Capital currently deployed as active advances (covering member entry gaps or missed rounds not yet recovered at selection) is not available for withdrawal — only undeployed capital is withdrawable
- AC-002-3: The depositor sees clearly before withdrawing: total deposited, yield earned to date, amount currently deployed, and withdrawable amount
- AC-002-4: Partial withdrawals are permitted with no minimum holding period or penalty
- AC-002-5: If a withdrawal would reduce pool capital below the formation threshold required for any active circle (see US-006), the withdrawal is capped at the amount that keeps the threshold intact. The depositor is shown a clear explanation and the earliest estimated date when the constraint lifts.

### US-003 · Enable Circle Entry (Entry Backstop)
**As a** member whose savings balance is below `circleAllocation`,
**I want** the Solidarity Pool to cover my entry gap,
**So that** I can join a savings circle before I have accumulated the full pool amount.

**Acceptance Criteria:**
- AC-003-1: At circle formation, if a queued member's `sharesBalance` is below `convertToShares(circleAllocation)`, the kickoff algorithm checks whether the Solidarity Pool has sufficient undeployed capital to cover the gap (`circleAllocation - convertToAssets(sharesBalance)`)
- AC-003-2: If covered: the gap amount in shares is recorded as `solidarityDebtShares` on the member's position. No interest is charged — the pool earns sUSDS yield on deployed capital; that is the full return.
- AC-003-3: If the pool cannot cover the gap, the member remains in the queue. The protocol notifies the member and may suggest a smaller `circleAllocation` tier that the pool can fully support at current depth.
- AC-003-4: All advances are tracked per-member and per-circle on-chain and are publicly auditable
- AC-003-5: A member entering via pool backstop has identical circle participation rights to a fully self-funded member — same selection probability, same payout, same obligation mechanics

### US-004 · Cover Missed Rounds (Round Coverage)
**As a** circle member who cannot cover a round contribution `D`,
**I want** the Solidarity Pool to cover my missed round automatically,
**So that** I remain in the draw and the circle continues uninterrupted for all other members.

**Acceptance Criteria:**
- AC-004-1: At each round boundary, if a member's withdrawable balance (net of existing obligations) is insufficient to cover `convertToShares(D)`, the Solidarity Pool covers the shortfall automatically — no member action required
- AC-004-2: The covered round is flagged on-chain (`solidarity_covered = true`) for that member's round entry. The covered amount in shares is added to the member's `solidarityDebtShares`.
- AC-004-3: The member remains eligible for selection in all subsequent rounds — a solidarity-covered round is not disqualifying and does not change selection probability
- AC-004-4: The member can resume contributing their own `D` in subsequent rounds without any explicit action. Normal rounds reduce the rate of debt accumulation; they do not retroactively clear flagged rounds (those are cleared at selection).
- AC-004-5: From the circle contract's perspective, `D` was received for that round (from the pool). Other circle members are unaffected — the circle proceeds normally.
- AC-004-6: A member whose every round from entry to selection is covered by the pool still receives the full payout at selection. Their debt (`(K-1) × D` where K is their selection round) is cleared from the payout, and the remainder is locked as `circleObligationShares`. The pool recovers fully; the member nets at least `D`.

### US-005 · Debt Settlement at Selection
**As a** member selected for payout with outstanding solidarity debt,
**I want** my debt cleared automatically from my payout,
**So that** the Solidarity Pool recovers its advance and I receive the net payout without any manual transaction.

**Acceptance Criteria:**
- AC-005-1: At selection, before setting `circleObligationShares`, the circle contract reads `solidarityDebtShares` from the selected member's position
- AC-005-2: If `solidarityDebtShares > 0`, those shares are transferred from the payout to the Solidarity Pool in the same transaction as the payout credit
- AC-005-3: Net `circleObligationShares = payoutShares - solidarityDebtShares`. This is always ≥ `convertToShares(D)` — the minimum net payout guarantee holds by construction.
- AC-005-4: `solidarityDebtShares` is reset to 0 on the member's position atomically with settlement
- AC-005-5: The settlement is atomic — payout credit, debt deduction, obligation lock, and pool repayment happen in a single transaction. No partial states are possible.
- AC-005-6: The member is shown a clear breakdown: gross payout in USDS-equivalent, solidarity debt cleared, net payout locked as obligation, and estimated yield on net payout at current APY

### US-006 · Pool Threshold and Circle Formation Eligibility
**As a** protocol,
**I need** the Solidarity Pool to hold sufficient capital before circles form with pool-dependent members,
**So that** every circle that forms can be sustained to completion even under worst-case defaults.

**Acceptance Criteria:**
- AC-006-1: For each pool-dependent member in a forming circle (a member whose entry gap the pool is covering), the pool must hold at least `(N-1) × D` in undeployed capital. This covers the worst case: the member defaults on every round and is selected last.
- AC-006-2: The pool threshold check is integrated into the kickoff algorithm (Spec 002 US-006 AC-006-1). A circle with zero pool-dependent members has no solidarity pool threshold requirement.
- AC-006-3: A governance-configurable `solidarityThresholdMultiplier` (default: 1.0×, range: 1.0–2.0×) scales the minimum threshold. A multiplier above 1.0 provides a buffer above the mathematical minimum.
- AC-006-4: If pool capital falls below the active threshold for an active circle mid-cycle (due to member withdrawals — see US-002 AC-002-5), further withdrawals are restricted until the threshold is restored. Circle continuity takes priority.
- AC-006-5: The pool's total depth, deployed amount, and available-for-new-formation capacity are all publicly readable on-chain in real time.

---

## Out of Scope for This Spec

- Secondary market for Solidarity Pool deposit positions (not in v1)
- Per-depositor attribution of which advances their capital funded (by design — the pool is anonymous and fungible; per-depositor tracking would enable gaming)
- Tiered depositor returns based on pool utilisation rate (future consideration)
- Automated solidarity pool deposit strategies (technically allowed but not protocol-provided)
- Cross-circle pool segmentation (single shared pool in v1 — segmentation adds complexity without meaningful benefit at launch scale)
- Interest charges on solidarity advances (by design — the return model is yield-only; interest would complicate the recovery math and misalign with the mutual aid framing)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | What is the minimum viable pool depth to launch — i.e., how much solidarity pool capital is needed before the first circle can form with pool-dependent members? This sets the bootstrapping requirement. | Protocol Economist | Open |
| OQ-002 | Should depositors receive any real-time signal about pool utilisation (current advance rate, number of active advances, estimated time to full recovery)? Full transparency may enable gaming (depositors withdrawing when advances are low); zero transparency feels opaque for a mutual system. | Product | Open |
| OQ-003 | How does the privacy layer interact with `solidarityDebtShares`? If positions are shielded, the pool contract cannot read `solidarityDebtShares` directly without revealing the member's full position state. A ZK proof of debt-in-range at selection may be required. | Protocol Architect | Open |
| OQ-004 | Should there be a per-member cap on `solidarityDebtShares` — a maximum the pool will advance to a single member? Without a cap, a member who joins with zero balance and misses every round accumulates `(N-1) × D`. The payout always covers this, but a governance cap may reduce protocol exposure concentration. | Product | Open |
