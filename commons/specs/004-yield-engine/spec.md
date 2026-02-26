# Spec 004 — Yield Engine

**Status:** Draft
**Version:** 0.1
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account)

---

## Overview

The Yield Engine is the protocol component responsible for routing member deposits to yield-generating sources and returning the yield to member savings accounts. It operates automatically, requires no management by members, and is designed to continue functioning if any single yield source fails.

The yield engine is a background infrastructure layer. Members never interact with it directly — they see only its output: their current APY and accrued yield in their Savings Account dashboard.

---

## Problem Statement

Real-world yield from short-duration government instruments and established money market positions is structurally inaccessible to most people because:

1. Tokenised treasuries require KYC at the issuance layer (they are accessible only to professional clients and licensed resellers)
2. Native DeFi yield (sDAI, Aave, Compound) is volatile and can collapse in downturns
3. Optimising across multiple sources requires active management that ordinary savers cannot perform

The Yield Engine abstracts all of this: it manages yield source allocation, rebalancing, and fallback logic automatically, presenting members with a single, stable-looking APY.

---

## User Stories

### US-001 · Automatic Yield Routing
**As a** member with a savings account,
**I want** my deposited balance to automatically earn yield from real-world sources,
**So that** I benefit from competitive rates without managing anything.

**Acceptance Criteria:**
- AC-001-1: Deposits are allocated to yield sources within 1 block of confirmation
- AC-001-2: The yield engine allocates across at minimum 2 yield sources to prevent single-source dependency
- AC-001-3: Allocation logic is deterministic and publicly auditable (the allocation algorithm is open source and verifiable)
- AC-001-4: The effective APY is shown to members in real time as a blended rate across all active sources
- AC-001-5: No member action is required to begin earning yield — it is automatic on deposit

### US-002 · Real-World Yield Sources
**As a** member,
**I want** yield to come from stable, real-world sources (not purely crypto-native),
**So that** my yield is not correlated with crypto market cycles.

**Acceptance Criteria:**
- AC-002-1: The protocol integrates with at minimum one tokenised money market fund or treasury product (e.g., Ondo OUSG, Superstate, or equivalent) for real-world yield exposure
- AC-002-2: Access to KYC-gated real-world yield sources is abstracted at the protocol layer — individual members do not KYC; the protocol entity holds the institutional relationship
- AC-002-3: The protocol also integrates with established DeFi savings protocols (Aave, Compound, or equivalent) as a supplementary source and fallback
- AC-002-4: The allocation between real-world and DeFi sources is governed by a target ratio (e.g., 70% real-world / 30% DeFi) configurable by governance within hard bounds
- AC-002-5: The identity of all active yield sources is publicly disclosed on-chain

### US-003 · Oracle Integration
**As a** protocol administrator,
**I want** yield rate data from external sources to be manipulation-resistant,
**So that** the protocol cannot be exploited through oracle manipulation.

**Acceptance Criteria:**
- AC-003-1: All real-world rate data is sourced from Chainlink Data Feeds or equivalent decentralised oracle networks
- AC-003-2: The protocol uses a minimum of 2 independent oracle sources for any rate used in allocation decisions
- AC-003-3: If oracle data is stale (> 1 hour since last update), the protocol switches to a conservative fallback rate rather than using stale data
- AC-003-4: Oracle manipulation attempts (rate deviations > 20% from the median of active sources) trigger a circuit breaker that pauses rebalancing until the deviation resolves
- AC-003-5: The circuit breaker does not pause withdrawals — members can always exit even during an oracle anomaly

### US-004 · Yield Reserve for Circle Buffer
**As a** circle participant,
**I need** the circle to continue functioning during a member's grace period,
**So that** a single member's temporary shortfall does not affect other members.

**Acceptance Criteria:**
- AC-004-1: A small portion of yield (configurable by governance, default: 5% of yield) is directed to a circle buffer reserve
- AC-004-2: The buffer reserve covers the contribution of paused members during their grace period
- AC-004-3: The buffer reserve is circle-specific — funds from one circle's reserve cannot be used to cover another circle
- AC-004-4: The buffer reserve is yield-bearing while idle (it earns yield via the same yield engine)
- AC-004-5: If the buffer reserve is insufficient to cover a paused member's contribution, the grace period shortfall is added to the paused member's `circleObligation` (to be repaid when they resume)

### US-005 · Protocol Fee
**As a** protocol (to fund ongoing development and audits),
**I need** a sustainable fee mechanism,
**So that** the protocol can fund operations without compromising member yield.

**Acceptance Criteria:**
- AC-005-1: The protocol charges a fee expressed as a percentage of yield earned (not principal) — default 10% of yield
- AC-005-2: The fee is deducted before yield is credited to member accounts — members see the net APY already fee-adjusted
- AC-005-3: The fee is transparent: the gross yield, fee amount, and net yield are all visible in the protocol's public dashboard
- AC-005-4: The fee rate is governable within hard bounds (floor: 0%, ceiling: 20%) — it cannot be changed outside these bounds even by governance
- AC-005-5: Fee revenue is directed to a multi-sig treasury controlled by protocol governance, not by any single party

---

## Out of Scope for This Spec

- Governance process for adjusting yield allocation parameters (covered in a future Governance spec)
- Cross-chain yield routing (v1 is single-chain; cross-chain is future work)
- Custom yield strategies for individual members (by design — the protocol abstracts yield management, not customises it)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Which specific real-world yield product do we integrate with first? Ondo OUSG and Superstate are the leading candidates. The choice affects the protocol entity's legal structure (who holds the KYC relationship). | Legal / Protocol Architect | Open |
| OQ-002 | What is the target minimum APY we commit to members? Or do we not commit to a minimum and show only the current blended rate? | Product | Open |
| OQ-003 | How does the yield engine interact with the privacy layer? If balances are shielded, how does the yield engine know how much to credit to each account without revealing balances on-chain? | Protocol Architect | Open |
| OQ-004 | Is the 5% buffer reserve allocation correct? Too high and it reduces member yield; too low and circles become fragile. | Protocol Economist | Open |
