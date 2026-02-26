# Spec 001 — Savings Account

**Status:** Draft
**Version:** 0.2
**Date:** February 2026
**Depends on:** Spec 004 (Yield Engine — YieldRouter must be deployed first)

---

## Changelog

**v0.2 (February 2026):**
- **Closed OQ-002:** SavingsAccount is NOT ERC-4626 externally. Internally it stores `sharesBalance` and `circleObligationShares` — share positions in the YieldRouter (which IS ERC-4626). No ERC20 share token is issued to members.
- **Updated Position struct:** all monetary values are stored as **shares**, not USDC. USDC-equivalent is derived on read via `yieldRouter.convertToAssets(sharesBalance)`.
- **Removed `creditYield()`:** yield accrues automatically via share price appreciation. Explicit yield crediting is no longer needed or possible.
- **Updated invariant:** `sharesBalance >= circleObligationShares` (was: `balance >= circleObligation`).
- **Added inflation-attack protection note:** storing the circle obligation in shares (not USDC) prevents an attacker from manipulating the pool size to reduce the effective obligation.
- **Dependency update:** SavingsAccount now depends on Spec 004 (YieldRouter deployed first), not None.

---

## Overview

The Savings Account is the foundational primitive of Mandinga Protocol. It is a self-custodial, yield-bearing position denominated in a dollar-stable asset (USDC or equivalent). Every member interaction with the protocol begins here.

The Savings Account does two jobs:

1. **Earn yield automatically** — deposits are routed to the YieldRouter (ERC4626), and yield accrues as share price appreciation. The member's USDC-equivalent balance grows without any explicit `creditYield()` call.
2. **Track and enforce the principal lock** — the minimum share balance that must be maintained to honour any outstanding circle obligations. The invariant is `sharesBalance >= circleObligationShares` at all times.

### Position Struct (v0.2)

```solidity
struct Position {
    uint256 sharesBalance;           // shares held in YieldRouter — NOT raw USDC
    uint256 circleObligationShares;  // minimum shares that cannot be redeemed
    uint256 lastYieldUpdate;         // retained for event/display purposes
    bool circleActive;
    bool vouchActive;
}
```

USDC-equivalent values are derived on read:
```
balance_usdc    = yieldRouter.convertToAssets(sharesBalance)
obligation_usdc = yieldRouter.convertToAssets(circleObligationShares)
withdrawable    = yieldRouter.convertToAssets(sharesBalance - circleObligationShares)
```

**Why shares and not USDC?**
- Yield is implicit — share price rises automatically, no per-position update needed
- Obligations are inflation-safe — storing obligations in shares means an attacker cannot manipulate the pool to reduce effective obligations
- Withdrawal math is clean — `sharesNeeded = convertToShares(usdcRequested)`, check `sharesBalance - sharesNeeded >= circleObligationShares`

The Savings Account can be used entirely standalone. A member who never activates the savings circle feature still has a fully functional, yield-bearing self-custodial position.

---

## Problem Statement

People with small balances earn yield on small balances. The compounding advantage requires capital. The Savings Account solves the first part of this: it gives everyone — regardless of balance size, geography, or identity — access to yield on whatever they can save, with no minimum balance requirements, no KYC, and no withdrawal restrictions beyond any active circle obligations.

---

## User Stories

### US-001 · Deposit and Earn
**As a** new member with a mobile wallet,
**I want to** deposit dollar-stable assets into a savings account,
**So that** my balance immediately begins earning yield without any manual management.

**Acceptance Criteria:**
- AC-001-1: A member can deposit any amount of USDC (≥ $1 minimum to prevent dust) into their savings account
- AC-001-2: Yield begins accruing from the block the deposit is confirmed — the deposit is routed to the YieldRouter and `sharesBalance` is immediately credited with `yieldRouter.convertToShares(depositAmount)` shares
- AC-001-3: No KYC, identity verification, or account creation is required
- AC-001-4: The member's position is represented internally as a `sharesBalance` — no ERC20 receipt token is issued (the position is non-transferable by design)
- AC-001-5: The current USDC-equivalent balance (`yieldRouter.convertToAssets(sharesBalance)`) is visible in real time

### US-002 · Withdraw Freely
**As a** member with a savings account,
**I want to** withdraw my balance at any time,
**So that** I maintain full custody and control of my funds.

**Acceptance Criteria:**
- AC-002-1: A member can withdraw any USDC amount up to `convertToAssets(sharesBalance - circleObligationShares)` at any time
- AC-002-2: The withdrawable USDC = `yieldRouter.convertToAssets(sharesBalance - circleObligationShares)`
- AC-002-3: If `circleObligationShares = 0`, the full share balance is redeemable
- AC-002-4: Withdrawals settle within 1 block — the contract calls `yieldRouter.withdraw(usdcAmount, member, savingsAccount)` which burns the corresponding shares
- AC-002-5: The member is shown their `circleObligation` in USDC-equivalent and their `withdrawableBalance` in USDC-equivalent clearly before confirming

### US-003 · View Position
**As a** member,
**I want to** see a clear breakdown of my savings position,
**So that** I understand exactly what I own, what is locked, and what I am earning.

**Acceptance Criteria:**
- AC-003-1: The position display shows (all values in USDC-equivalent, derived via `convertToAssets()`): total balance, locked amount (circle obligation), available to withdraw, yield earned to date, current APY
- AC-003-2: Balance updates are event-driven from YieldRouter share price changes — no per-block on-chain update is needed; the frontend recalculates `convertToAssets(sharesBalance)` on each view
- AC-003-3: Historical yield earned = `convertToAssets(sharesBalance) - totalDeposited` — always derivable from on-chain state, even after partial withdrawals

### US-004 · Principal Lock Enforcement
**As a** member with an active circle participation,
**I need** my balance to always cover my circle obligation,
**So that** the circle's structural enforcement works without human intervention.

**Acceptance Criteria:**
- AC-004-1: The contract enforces `sharesBalance >= circleObligationShares` at all times — this is the invariant checked on every state-modifying function
- AC-004-2: Any withdrawal attempt where `sharesBalance - convertToShares(requestedUsdc) < circleObligationShares` is rejected with `InsufficientWithdrawableBalance(requestedUsdc, withdrawableUsdc)`
- AC-004-3: As share price rises (yield accrues), `convertToAssets(sharesBalance - circleObligationShares)` increases automatically — the member's withdrawable USDC grows without any on-chain action
- AC-004-4: The principal lock is enforced purely in the contract. No human action, DAO vote, or `harvest()` call is required to maintain it.

### US-005 · Emergency Exit
**As a** member in any state,
**I must** always be able to recover my funds if the protocol is paused or deprecated,
**So that** self-custody is real, not theoretical.

**Acceptance Criteria:**
- AC-005-1: An emergency exit function allows withdrawal of the full balance (including locked portion) in a protocol emergency state
- AC-005-2: The emergency state can only be declared by a time-locked governance process (minimum 7-day delay)
- AC-005-3: In an emergency state, circle obligations are considered settled and the principal lock is released
- AC-005-4: The emergency exit path is audited and tested independently of the normal withdrawal path

---

## Out of Scope for This Spec

- Yield routing logic (covered in Spec 004 — Yield Engine)
- Circle participation mechanics (covered in Spec 002 — Savings Circle)
- Vouching mechanics (covered in Spec 003 — Solidarity Market)
- Multi-asset support beyond dollar-stable assets (future consideration)
- Native token support without stable bridge (excluded by design — we do not expose members to speculative asset volatility)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Which privacy layer do we use? (Aztec, zkSync private state, or custom ZK circuit?) The answer changes how `sharesBalance` is stored and read. | Protocol Architect | Open |
| OQ-002 | ~~Is the receipt token ERC-4626 compliant?~~ **Resolved:** SavingsAccount is NOT ERC-4626 externally. It stores `sharesBalance` (a `uint256`) from the YieldRouter, which IS ERC-4626 internally. No ERC20 share token is issued to members. The position is non-transferable by design. | Smart Contract Lead | **Closed** |
| OQ-003 | Minimum deposit: $1 USDC is proposed to prevent dust. Is this the right floor? Should it be configurable by governance? | Product | Open |
| OQ-004 | Do we support multiple dollar-stable assets (USDC, USDT, DAI) from day one, or USDC only? | Product | Open |
| OQ-A | (From Spec 004) YieldRouter ERC20 share transferability — affects whether `SavingsAccount` can hold shares as a `uint256` or must call `balanceOf()`. Recommend: YieldRouter mints shares to SavingsAccount address but `transfer()` is blocked — `sharesBalance` is read via `yieldRouter.balanceOf(address(this))` or maintained internally. Needs decision before Task 001-02. | Smart Contract Lead | Open |
| OQ-B | (From Spec 004) Adapter exploit / share price floor — if an adapter is exploited and `totalAssets()` collapses, all `sharesBalance` values lose USDC value instantly. Does SavingsAccount need a minimum redemption guarantee, or does the 60% per-adapter cap make this acceptable? | Protocol Architect | Open |
