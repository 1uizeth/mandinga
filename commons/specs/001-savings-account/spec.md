# Spec 001 — Savings Account

**Status:** Draft
**Version:** 0.1
**Date:** February 2026
**Depends on:** None (foundational primitive)

---

## Overview

The Savings Account is the foundational primitive of Commons Protocol. It is a self-custodial, yield-bearing position denominated in a dollar-stable asset (USDC or equivalent). Every member interaction with the protocol begins here.

The Savings Account does two jobs:

1. **Earn yield automatically** on the deposited balance from real-world sources, routed by the protocol's yield engine.
2. **Track and enforce the principal lock** — the minimum balance that must be maintained to honour any outstanding circle obligations.

The Savings Account can be used entirely standalone. A member who never activates the savings circle feature still has a fully functional, yield-bearing self-custodial savings position.

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
- AC-001-2: Yield begins accruing from the block the deposit is confirmed
- AC-001-3: No KYC, identity verification, or account creation is required
- AC-001-4: The member receives a non-transferable receipt token representing their position
- AC-001-5: The current balance (principal + accrued yield) is visible in real time

### US-002 · Withdraw Freely
**As a** member with a savings account,
**I want to** withdraw my balance at any time,
**So that** I maintain full custody and control of my funds.

**Acceptance Criteria:**
- AC-002-1: A member can withdraw their full balance at any time, subject only to the principal lock
- AC-002-2: The withdrawable amount equals `balance - circleObligation`
- AC-002-3: If `circleObligation = 0`, the full balance is withdrawable
- AC-002-4: Withdrawals settle within 1 block (no withdrawal queue for standard amounts)
- AC-002-5: The member is shown their current `circleObligation` and `withdrawableBalance` clearly before confirming a withdrawal

### US-003 · View Position
**As a** member,
**I want to** see a clear breakdown of my savings position,
**So that** I understand exactly what I own, what is locked, and what I am earning.

**Acceptance Criteria:**
- AC-003-1: The position display shows: total balance, locked amount (circle obligation), available to withdraw, yield earned to date, current yield rate (APY)
- AC-003-2: The position is updated on every block (or via efficient event-driven updates)
- AC-003-3: Historical yield earned is always visible, even after full withdrawal of principal

### US-004 · Principal Lock Enforcement
**As a** member with an active circle participation,
**I need** my balance to always cover my circle obligation,
**So that** the circle's structural enforcement works without human intervention.

**Acceptance Criteria:**
- AC-004-1: The contract enforces `balance >= circleObligation` at all times
- AC-004-2: Any withdrawal attempt that would reduce `balance` below `circleObligation` is rejected with a clear error message showing the shortfall
- AC-004-3: If yield accrual brings the balance above `circleObligation`, the member is notified of their new withdrawable balance
- AC-004-4: The principal lock is enforced purely by contract logic; no human action or DAO vote is required to maintain it

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
| OQ-001 | Which privacy layer do we use? (Aztec, zkSync private state, or custom ZK circuit?) The answer changes how the balance is stored and read. | Protocol Architect | Open |
| OQ-002 | Is the receipt token ERC-4626 compliant? ERC-4626 gives composability but may expose balance information depending on the privacy layer. | Smart Contract Lead | Open |
| OQ-003 | Minimum deposit: $1 USDC is proposed to prevent spam. Is this the right floor? Should it be configurable by governance? | Product | Open |
| OQ-004 | Do we support multiple dollar-stable assets (USDC, USDT, DAI) from day one, or USDC only? | Product | Open |
