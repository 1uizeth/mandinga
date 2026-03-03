# Spec 003 — Safety Net Pool

**Status:** Draft
**Version:** 1.0
**Date:** March 2026
**Depends on:** Spec 001 (Savings Account), Spec 002 (Savings Circle)

---

## Changelog

**v1.0 (March 2026):**
- **Complete rewrite.** Replaced the bilateral vouching / Solidarity Market model with the Safety Net Pool — the mechanism that enables minimum installment coverage for circle participants.
- **Core mechanic simplified.** The pool covers the gap between `minDepositPerRound` and `depositPerRound` when a member activates the minimum option. Previously the pool backed full `circleAllocation` per member — this is removed.
- **Reallocation support added.** Pool temporarily covers an open position when a member is reallocated (Spec 002 US-008), giving the protocol time to find a replacement member.
- **USDC throughout.** Replaced USDS.

**v0.4 (February 2026) — archived:**
- Insurance model with full `circleAllocation` backing per member. Lock periods. `solidarityDebtShares` as running balance.

---

## Overview

The Safety Net Pool is the mechanism that makes minimum installment coverage possible. Members with idle savings capacity deposit capital into the pool, lock it for a declared duration, and earn yield on it — the same yield their capital would earn in a standalone Savings Account. In exchange, that capital covers the gap when circle participants need to use the minimum installment option.

**The core mechanic:**

When a circle member activates the minimum installment option (Spec 002 US-007), they pay `minDepositPerRound` each round instead of the full `depositPerRound`. The Safety Net Pool covers the difference — `depositPerRound − minDepositPerRound` — each covered round. The member's `safetyNetDebtShares` increases by `convertToShares(depositPerRound − minDepositPerRound)` per covered round. At selection, `safetyNetDebtShares` is settled atomically from the gross payout before the net obligation is locked.

**What pool depositors get:**

USDC yield on their locked capital — the same yield they would earn in a standalone Savings Account — plus the interest paid by covered members on their `safetyNetDebtShares`. The interest is a small, transparent fee. The depositor's capital earns regardless of whether it is currently covering anyone.

**What the pool makes possible:**

A member does not need a large balance to join a circle. They need capacity to pay `minDepositPerRound` per round. The pool covers the gap. This eliminates the entry barrier without requiring the member to have the full `circleAllocation` upfront.

The pool also provides **reallocation support**: when a member cannot sustain even `minDepositPerRound` and is reallocated out of a circle (Spec 002 US-008), the pool temporarily covers the open position while a replacement member is matched from the queue. This keeps the circle running with minimal disruption to remaining members.

---

## Problem Statement

Two scenarios break a circle's integrity without a safety net:

1. A member cannot pay the full `depositPerRound` in a given round but can pay at least `minDepositPerRound`
2. A member cannot pay even `minDepositPerRound` and must exit the circle

Both create a gap the circle cannot absorb alone. The Safety Net Pool fills gap (1) automatically and buffers gap (2) while the circle is corrected. In both cases, the circle continues. Members in the circle see at most a temporary adjustment, not a failure.

---

## User Stories

### US-001 · Deposit into the Safety Net Pool
**As a** member with idle savings capacity,
**I want to** deposit capital into the Safety Net Pool with a declared lock duration,
**So that** my capital earns yield while enabling minimum installment coverage for others.

**Acceptance Criteria:**
- AC-001-1: A member can deposit any USDC amount (≥ \$1 minimum) into the Safety Net Pool, specifying a lock duration (same unit input as `duration` in Spec 002: days / weeks / months / years)
- AC-001-2: Deposited capital is routed to the YieldRouter immediately — the pool holds YieldRouter shares, not USDC. Yield accrues via share price appreciation from block 1
- AC-001-3: Before being actively used for coverage, deposited capital is **undeployed** — it earns yield and is freely withdrawable. The depositor sees: USDC-equivalent deposited, yield accrued, lock duration declared, deployed vs undeployed split
- AC-001-4: The pool may use undeployed capital for coverage at any time during the declared lock duration. Once used, that portion is locked until the debt is settled at the covered member's selection or the reallocation is resolved
- AC-001-5: A depositor may have multiple pool positions with different lock durations simultaneously

### US-002 · Withdraw from the Safety Net Pool
**As a** Safety Net Pool depositor,
**I want to** withdraw my capital after my lock period,
**So that** I recover my principal and accrued yield once my commitment is fulfilled.

**Acceptance Criteria:**
- AC-002-1: Capital that is undeployed (not currently covering any member) is withdrawable at any time regardless of declared lock duration
- AC-002-2: Capital that is actively deployed (covering a member's minimum installment gap or an open reallocation slot) is locked until that coverage resolves — either at the covered member's selection or when a replacement member joins
- AC-002-3: When coverage resolves, deployed capital + accrued yield is automatically returned to the depositor's withdrawable pool balance. No claim transaction required
- AC-002-4: The depositor sees clearly: total deposited, yield earned, amount deployed (with estimated resolution timeline), and withdrawable amount
- AC-002-5: After withdrawal, the depositor's Savings Account `sharesBalance` is credited with the equivalent shares

### US-003 · Cover Minimum Installment Gap
**As a** circle participant using the minimum installment option,
**The Safety Net Pool** covers the gap between `minDepositPerRound` and `depositPerRound` each covered round.

**Acceptance Criteria:**
- AC-003-1: When the minimum installment option is active for a member (Spec 002 US-007 AC-007-2 or AC-007-3), the pool covers `depositPerRound − minDepositPerRound` each round from available capital
- AC-003-2: The circle contract receives the full `depositPerRound` regardless of source — it does not distinguish member-funded and pool-funded portions
- AC-003-3: The covered member's `safetyNetDebtShares` increases by `convertToShares(depositPerRound − minDepositPerRound)` each covered round
- AC-003-4: Interest accrues on `safetyNetDebtShares` at the **coverage rate** (see OQ-005). Interest is charged from the member's yield earnings before they reach the member's position — transparent and automatic
- AC-003-5: The member's position display shows the current `safetyNetDebtShares`, accrued interest to date, and estimated net payout at current APY

### US-004 · Settle Debt at Selection
**As a** pool-covered member selected for payout,
**The Safety Net Pool** recovers its advance atomically before the net obligation is locked.

**Acceptance Criteria:**
- AC-004-1: At selection, the circle contract reads `safetyNetDebtShares` on the selected member's position
- AC-004-2: If `safetyNetDebtShares > 0`, those shares are transferred from the gross payout to the Safety Net Pool in the same transaction as the payout credit — before `circleObligationShares` is set
- AC-004-3: Net `circleObligationShares = convertToShares(remainingRounds × depositPerRound) − safetyNetDebtShares`. Always ≥ 0 (the payout = N × depositPerRound; maximum debt = N × (depositPerRound − minDepositPerRound); minimum net is bounded by minDepositPerRound contributions)
- AC-004-4: `safetyNetDebtShares` is reset to 0 atomically with settlement
- AC-004-5: Deployed pool capital that was covering this member's gap is released back to the depositor's undeployed balance
- AC-004-6: The member receives a breakdown: gross payout (USDC-equivalent), Safety Net Pool debt cleared, net obligation locked, yield projection on the net obligation

### US-005 · Reallocation Support
**As a** circle with a member who cannot sustain even `minDepositPerRound`,
**The Safety Net Pool** temporarily covers the open position while a replacement is found.

**Acceptance Criteria:**
- AC-005-1: When a member is reallocated out of a circle (Spec 002 US-008 AC-008-3), the Safety Net Pool temporarily covers the open position for up to a governance-configurable window (e.g., 3 rounds), giving the protocol time to match a replacement
- AC-005-2: During the coverage window, remaining circle members continue receiving their rounds normally. The temporarily covered slot earns yield on the pool's capital
- AC-005-3: If a replacement member joins within the coverage window, they absorb the open position and the pool's temporary coverage ends
- AC-005-4: If no replacement is found within the coverage window, the circle adjusts to N-1 members (slightly smaller pool) and the pool's coverage ends
- AC-005-5: Pool capital used for reallocation support is returned when the coverage window closes or a replacement joins

### US-006 · Pool Depth and Availability
**As a** protocol,
**I need** the pool to hold sufficient capital to cover minimum installment gaps and support reallocation,
**So that** circles can form and run with the minimum installment option enabled.

**Acceptance Criteria:**
- AC-006-1: A circle can form with minimum-installment-enabled members only if the pool holds sufficient undeployed capital to cover at least one full `duration` of gap payments per such member: `(depositPerRound − minDepositPerRound) × N rounds` per covered member
- AC-006-2: This check is performed by the kickoff algorithm (Spec 002 US-006) — prerequisite for including minimum-installment members in a candidate circle, not post-formation
- AC-006-3: A circle composed entirely of members paying full `depositPerRound` (no minimum option) has no pool depth requirement
- AC-006-4: The pool's available capital breakdown is publicly readable on-chain: total deposited, total deployed, total undeployed, average yield earned

---

## Out of Scope for This Spec

- Full `circleAllocation` backing per member (removed — pool covers installment gap only, not full pool size)
- Bilateral vouching / Solidarity Market (removed — replaced by this spec)
- Per-depositor attribution of which members their capital covered (pool is fungible; attribution enables gaming)
- Secondary market for pool deposit positions (not in v1)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Minimum pool depth required to launch first circle with minimum-installment members? Sets bootstrapping requirement and go-to-market sequencing. | Protocol Economist | Open |
| OQ-002 | Reallocation coverage window: how many rounds should the pool cover an open slot before the circle adjusts to N-1? Default proposal: 3 rounds. | Product | Open |
| OQ-003 | Lock duration matching: should the pool preferentially deploy capital with the shortest or longest available lock? Shortest maximises depositor flexibility; longest maximises coverage commitment. | Protocol Economist | Open |
| OQ-004 | Privacy interaction: if positions are shielded, the pool contract cannot directly read `safetyNetDebtShares`. A ZK proof of debt-in-range may be required for atomic settlement. Deferred to v2 privacy layer. | Protocol Architect | Deferred |
| OQ-005 | Coverage interest rate: APY-linked (self-adjusting, market-fair) vs fixed governance-set rate (predictable for members)? APY-linked compensates depositors at market rate but introduces variability in what members owe. | Protocol Economist | Open |
