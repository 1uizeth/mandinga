# Spec 003 — Solidarity Pool

**Status:** Draft
**Version:** 0.4
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account), Spec 002 (Savings Circle)

---

## Changelog

**v0.4 (February 2026):**
- **Collapsed entry backstop and round coverage into one mechanism.** The previous v0.3 distinction was artificial — both are instances of the same thing: the pool backing the full `circleAllocation` for a member. There is no "entry gap" and "missed round" as separate concepts. There is only: how much of the member's `circleAllocation` has the member covered themselves, and how much does the pool still hold.
- **Insurance model formalised.** The pool acts as an insurer. Depositors lock capital for a declared duration and earn yield on it — that yield is the insurance premium equivalent. The policy activates automatically when `accountBalance < depositPerRound`. Once activated, the pool commits to covering all remaining rounds, not just the current one.
- **Lock periods introduced.** Pool deposits are locked for a duration declared by the depositor. Capital is matched to circles whose `circleDuration` ≤ the depositor's declared lock. Once matched to a circle, capital is locked until that circle completes (all members selected). Lock periods are what make the insurance economically sound: the pool cannot withdraw while it is backing an active circle.
- **`solidarityDebtShares` simplified.** No longer an accumulation of per-round flags. It is a single running balance: `convertToShares(circleAllocation - own_contributions_so_far)`, decreasing as the member contributes and cleared at selection.
- **v0.3 mechanisms archived.** Per-round `solidarity_covered` flags and the two-path entry check are removed.

**v0.3 (February 2026):**
- [archived — two-mechanism model: entry backstop + round coverage]

**v0.2 (February 2026):**
- [archived — bilateral peer vouching model]

---

## Overview

The Solidarity Pool is the insurance layer of Mandinga Protocol. Members with idle savings capacity deposit capital into the pool, lock it for a declared duration, and earn yield on it. In exchange, that capital guarantees circle continuity for members who cannot sustain their round contributions — covering their `circleAllocation` in full if needed, recoverable when the covered member is selected.

**The core mechanic is one thing, not two:**

When a circle forms with a pool-backed member, the pool reserves `circleAllocation` worth of capital for that member. The member contributes `D` each round from their own balance, reducing the pool's exposure. If at any round their `accountBalance < depositPerRound`, the pool's insurance activates — the pool covers that round and commits to covering all remaining rounds until selection. The member's debt is always:

```
solidarityDebt = circleAllocation − own_contributions_so_far
```

At selection, the payout first clears `solidarityDebt`. The remainder is locked as `circleObligationShares`. Because payout = `N × D` and maximum debt = `N × D` (if member never contributed), the pool's advance is always fully recovered.

**Why lock periods:**

The pool cannot back a circle for 10 months if its capital can be withdrawn in month 3. Lock periods align depositor commitments with the circles they back. Once the protocol matches a depositor's capital to a circle, that capital is locked until the circle completes. Before matching, the capital earns yield and is freely withdrawable.

**The return for depositors:**

sUSDS yield on locked capital — the same yield the capital would earn in a standalone Savings Account. The depositor is not earning less for locking; they earn the same yield they would anyway, and the lock is what makes the insurance credible. There is no premium above base yield. The value proposition is: your idle capital earns yield regardless, and while it does, it guarantees that circles can form and survive.

---

## Problem Statement

A member who wants to join a circle but cannot sustain monthly contributions faces two failure modes:
1. Their balance is below `circleAllocation` at entry — they cannot join.
2. They join but hit a financial shortfall mid-circle — they cannot contribute `D` for one or more rounds.

Both are the same underlying problem: their capital is insufficient to guarantee the circle's integrity. The Solidarity Pool solves both with one mechanism.

The pool also solves a structural problem for the circle: in a traditional ROSCA, if a member stops contributing before selection, the remaining members are shortchanged. On-chain, the principal lock (Spec 001) prevents a member from withdrawing below their obligation — but if the member never had sufficient capital to begin with, the lock alone is not enough. The pool is the capital guarantee that the lock cannot be.

---

## User Stories

### US-001 · Deposit and Lock
**As a** member with idle savings capacity,
**I want to** deposit capital into the Solidarity Pool with a declared lock duration,
**So that** my capital earns yield while serving as insurance for circle participants over that period.

**Acceptance Criteria:**
- AC-001-1: A member can deposit any USDS amount (≥ $1 minimum) into the Solidarity Pool, specifying a lock duration (same unit input as `circleDuration`: days / weeks / months / years)
- AC-001-2: Deposited capital is routed to the YieldRouter immediately — the pool holds YieldRouter shares, not USDS. Yield accrues via share price appreciation from block 1, regardless of whether the capital has been matched to a circle yet.
- AC-001-3: Before matching, deposited capital is **undeployed** — it earns yield and is freely withdrawable. The depositor sees: USDS-equivalent deposited, yield accrued, lock duration declared, deployed vs undeployed split.
- AC-001-4: The protocol matches undeployed capital to forming circles whose `circleDuration ≤` depositor's declared lock duration. Matching is automatic — no action required from the depositor. The depositor is notified when their capital is matched and the lock begins.
- AC-001-5: Once matched to a circle, the capital is locked until that circle completes (all N members selected). Early withdrawal of matched capital is not permitted — the lock is enforced by the contract.
- AC-001-6: A depositor may have multiple pool positions with different lock durations simultaneously (e.g., $500 locked for 3 months backing circle A, $1,000 locked for 12 months available for longer circles).

### US-002 · Withdraw
**As a** Solidarity Pool depositor,
**I want to** withdraw my capital after my lock period,
**So that** I recover my principal and accrued yield once my commitment is fulfilled.

**Acceptance Criteria:**
- AC-002-1: Capital that is undeployed (not yet matched to any circle) is withdrawable at any time, regardless of declared lock duration
- AC-002-2: Capital that is deployed (matched to an active circle) is locked until that circle completes — no exceptions, no early exit
- AC-002-3: When a circle completes, deployed capital + accrued yield is automatically returned to the depositor's withdrawable pool balance. No claim transaction is required.
- AC-002-4: The depositor sees clearly at all times: total deposited, yield earned, amount deployed to active circles (with estimated completion dates), and withdrawable amount
- AC-002-5: After withdrawal, the depositor's Savings Account `sharesBalance` is credited with the equivalent shares — the capital returns to their savings position

### US-003 · Back a Circle Participant
**As a** circle participant whose balance may be insufficient to guarantee contributions,
**As a** protocol forming a circle,
**The Solidarity Pool** covers the full `circleAllocation` for members who need it, activating automatically when their account balance falls below `depositPerRound`.

**Acceptance Criteria:**
- AC-003-1: At circle formation, if a queued member's `sharesBalance` is below `convertToShares(circleAllocation)`, the protocol checks whether the pool holds sufficient matched capital (i.e., capital with declared lock ≥ `circleDuration`) to reserve `circleAllocation` for that member. If yes, the member joins. If no, the member remains queued.
- AC-003-2: At circle formation, the pool reserves `circleAllocation` worth of shares for each pool-backed member. This reservation is locked for the circle's `circleDuration`. The reserved capital continues earning yield in the YieldRouter while waiting.
- AC-003-3: Each round, the protocol first attempts to deduct `D` from the member's own withdrawable balance. If `accountBalance ≥ depositPerRound`, the member self-funds that round and the pool's reservation is unchanged.
- AC-003-4: If `accountBalance < depositPerRound` at any round, the pool's insurance activates. The pool covers that round from the reservation and **commits to covering all remaining rounds** — the insurance does not toggle off even if the member's balance later recovers above `depositPerRound`. This prevents an unpredictable on/off state.
- AC-003-5: `solidarityDebtShares` is updated each round: `solidarityDebtShares = convertToShares(circleAllocation − own_contributions_so_far)`. It is a single running balance, not an accumulation of per-round flags.
- AC-003-6: A pool-backed member has identical circle participation rights to a fully self-funded member — same selection probability (VRF), same payout, same obligation mechanics post-selection.
- AC-003-7: The member's position display shows: their total `circleAllocation`, amount covered by own contributions so far, amount currently backed by the pool, and estimated net payout at current APY.

### US-004 · Debt Settlement at Selection
**As a** pool-backed member selected for payout,
**The pool** recovers its advance automatically and atomically before locking the member's net obligation.

**Acceptance Criteria:**
- AC-004-1: At selection, the circle contract reads `solidarityDebtShares` on the selected member's position
- AC-004-2: If `solidarityDebtShares > 0`, those shares are transferred from the payout to the Solidarity Pool in the same transaction as the payout credit — before setting `circleObligationShares`
- AC-004-3: Net `circleObligationShares = payoutShares − solidarityDebtShares`. This is always ≥ `convertToShares(D)`: payout = `N × D`, max debt = `N × D` (zero contributions), minimum net = 0. If the member contributed at least one round, net is always positive.
- AC-004-4: `solidarityDebtShares` is reset to 0 atomically with settlement
- AC-004-5: The pool's reservation for this member is released. Matched capital that was reserved but not deployed (because the member self-funded some rounds) returns to the depositor's deployable balance.
- AC-004-6: The member receives a clear breakdown: gross payout in USDS-equivalent, solidarity debt cleared, net obligation locked, and yield projection on the net obligation at current APY.

### US-005 · Pool Depth and Circle Formation Eligibility
**As a** protocol,
**I need** the pool to hold sufficient matched capital before backing members in a forming circle,
**So that** every circle that forms has its continuity guaranteed for its full duration.

**Acceptance Criteria:**
- AC-005-1: A circle can only form with pool-backed members if the pool holds at least `circleAllocation` in undeployed capital with declared lock ≥ `circleDuration` per pool-backed member in the forming circle
- AC-005-2: This check is performed by the kickoff algorithm (Spec 002 US-006) — it is a prerequisite for including pool-backed members in a candidate circle, not a post-formation check
- AC-005-3: A circle composed entirely of self-funded members (all with `sharesBalance ≥ circleAllocation`) has no pool depth requirement
- AC-005-4: The pool's available-by-duration breakdown is publicly readable on-chain: for any given `circleDuration`, how much capital is available and matched
- AC-005-5: A governance-configurable `reserveMultiplier` (default 1.0×, range 1.0–2.0×) scales the reservation per backed member above the mathematical minimum. A multiplier above 1.0 keeps a buffer in the pool beyond the worst-case advance.

---

## Out of Scope for This Spec

- Per-depositor attribution of which circles their capital backed (by design — pool is fungible; attribution enables gaming)
- Tiered yield rates based on lock duration (all depositors earn the same sUSDS rate; lock duration affects matching eligibility, not yield)
- Partial insurance (pool backing a fraction of `circleAllocation`) — the pool backs the full amount or not at all, keeping debt accounting simple
- Secondary market for pool deposit positions (not in v1)
- Automated pool deposit strategies (technically allowed, not protocol-provided)
- Cross-pool segmentation (single shared pool in v1)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | What is the minimum pool depth required to launch the first circle with pool-backed members? This sets the bootstrapping requirement and determines the go-to-market sequencing. | Protocol Economist | Open |
| OQ-002 | Once insurance activates (`accountBalance < depositPerRound`), the pool commits to all remaining rounds. Should the member's subsequent contributions (if their balance recovers) reduce `solidarityDebtShares` anyway, or is the debt fixed at activation? Allowing reductions keeps the debt accurate; fixing it at activation simplifies accounting but overstates the pool's exposure. | Product | Open |
| OQ-003 | Lock duration matching: should the protocol match capital to the longest available circle first (maximises lock utilisation) or the shortest (maximises depositor flexibility)? | Protocol Economist | Open |
| OQ-004 | How does the privacy layer interact with `solidarityDebtShares` at selection? If positions are shielded, the pool contract cannot read the debt directly. A ZK proof of `solidarityDebtShares`-in-range may be required for the atomic settlement. | Protocol Architect | Open |
| OQ-005 | Should there be a maximum pool backing per member — a cap on `circleAllocation` the pool will fully back? Without a cap, a member with zero balance joining the highest-tier circle consumes the most pool capital. A tier-based cap (e.g., pool backs up to a `circleAllocation` equivalent to X% of current pool depth) may be a useful governance guardrail. | Product | Open |
