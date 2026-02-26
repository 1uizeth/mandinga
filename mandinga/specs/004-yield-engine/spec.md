# Spec 004 — Yield Engine

**Status:** Draft
**Version:** 0.2
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account)

---

## Changelog

**v0.2 (February 2026):**
- Added ERC4626 Meta-Vault architecture section — resolves OQ-003 and the Merkle-drop problem
- Updated `harvest()` model: fee + buffer deducted, net yield stays in pool, share price appreciates automatically — no per-position distribution required
- Updated CircleBuffer: now holds YieldRouter shares, earns yield passively (closes AC-004-4 ambiguity)
- Closed OQ-003 (privacy layer / yield interaction — resolved by share price model)
- Added OQ-A through OQ-E from architectural analysis with Luan

---

## Overview

The Yield Engine is the protocol component responsible for routing member deposits to yield-generating sources and returning yield to member positions. It operates automatically, requires no management by members, and is designed to continue functioning if any single yield source fails.

**The YieldRouter is ERC4626-compliant internally.** It acts as a meta-vault aggregating yield across multiple adapters. The `SavingsAccount` stores member positions as *shares* in the YieldRouter — not as raw USDC amounts. Yield accrues through share price appreciation: as the pool earns yield, `totalAssets()` grows and every share is worth more USDC. No per-position yield credits are ever needed, and no Merkle-drop is required.

The yield engine is a background infrastructure layer. Members never interact with it directly — they see only its output: their current APY and USDC-equivalent balance in their Savings Account dashboard.

---

## ERC4626 Architecture

### Two-Layer Design

```
SavingsAccount (user-facing — stores sharesBalance internally, NOT ERC20-transferable)
       │
       │  deposit(usdc)   ──►  receives shares (internal accounting only)
       │  withdraw(usdc)  ──►  redeems shares  (internal accounting only)
       ▼
YieldRouter [ERC4626 compliant — access restricted to SavingsAccount only]
  - asset():          USDC
  - totalAssets():    sum of all adapter balances + idle USDC in contract
  - convertToShares() / convertToAssets() — share price accounting
       │
       ├── AaveAdapter    → Aave V3 Pool → aUSDC
       └── OndoAdapter    → Ondo OUSG / Superstate (real-world yield)
```

This resolves the three tensions between ERC4626 and Mandinga's requirements:

| Tension | Resolution |
|---|---|
| Shares are ERC20-transferable by default | `SavingsAccount` stores `sharesBalance` as a `uint256` — no ERC20 share token is ever issued to members |
| `totalAssets()` exposes TVL | TVL is intentionally public for solvency verification; individual positions remain shielded in `SavingsAccount` |
| ERC4626 has no `circleObligation` awareness | `SavingsAccount` stores `circleObligationShares` and enforces the lock before any share redemption |

### Critical ERC4626 Overrides

**`totalAssets()`** — aggregates all adapters:
```solidity
function totalAssets() public view override returns (uint256) {
    uint256 total = IERC20(asset()).balanceOf(address(this)); // idle USDC
    for (uint256 i = 0; i < activeAdapters.length; i++) {
        total += IYieldSourceAdapter(activeAdapters[i]).getBalance();
    }
    return total;
}
```

**`_deposit()`** — routes to adapters after receiving USDC:
```solidity
function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
    super._deposit(caller, receiver, assets, shares); // pulls USDC in, mints shares
    _routeToAdapters(assets);
    emit CapitalAllocated(assets, block.timestamp);
}
```

**`_withdraw()`** — pulls from adapters before sending USDC out (waterfall):
```solidity
function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {
    _pullFromAdapters(assets);
    super._withdraw(caller, receiver, owner, assets, shares); // burns shares, transfers USDC
    emit CapitalWithdrawn(assets, block.timestamp);
}
```

**Access restriction** — only `SavingsAccount` can call `deposit()`/`withdraw()`:
```solidity
modifier onlySavingsAccount() {
    require(msg.sender == savingsAccount, "ONLY_SAVINGS_ACCOUNT");
    _;
}
```

### How Yield Distribution Works — Share Price Appreciation

**Old model (v0.1):** `harvest()` → distribute yield to N positions → O(N) gas → Merkle-drop workaround required.

**New model (v0.2):** `harvest()` → deduct fee and buffer → net yield stays in pool → `totalAssets()` grows → share price rises automatically → **zero gas per position.**

```
Day 0:  deposit 200 USDC → 200 shares minted (price = 1.000000)

harvest() after 30 days:
  gross yield collected = 0.80 USDC
  fee (10%)             = 0.08 USDC → treasury (leaves pool)
  buffer (5%)           = 0.04 USDC → CircleBuffer (leaves pool as shares)
  net yield             = 0.68 USDC stays in pool

totalAssets() = 200.68 USDC  |  shares outstanding = 200
share price   = 200.68 / 200 = 1.0034

Member balance = convertToAssets(200 shares) = 200.68 USDC  ← no explicit creditYield() needed
```

The `creditYield()` function is eliminated entirely from the protocol's design.

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
- AC-004-1: 5% of gross yield (configurable by governance) is directed to the `CircleBuffer` contract at each `harvest()`
- AC-004-2: The `CircleBuffer` deposits received USDC into the YieldRouter and holds the resulting **shares** — it earns yield passively via share price appreciation while idle (no separate yield mechanism needed)
- AC-004-3: The buffer reserve is circle-specific — each circle's buffer holds its own `sharesBalance` in the CircleBuffer contract; cross-circle access is prohibited
- AC-004-4: When a paused member's grace period slot is covered, shares are redeemed from the buffer at the current share price to obtain USDC
- AC-004-5: If the buffer's redeemable USDC is insufficient to cover the paused slot, the shortfall is added to the paused member's `circleObligationShares` (to be settled on resume)

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

## Out of Scope

- Governance process for yield allocation parameters (future Governance spec)
- Cross-chain yield routing (v1 is single-chain)
- Custom yield strategies per member (by design)
- Merkle-drop yield distribution (removed — share price appreciation replaces this entirely)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Which real-world yield product do we integrate with first? Ondo OUSG and Superstate are candidates. Choice affects the legal structure for the KYC relationship. | Legal / Architect | Open |
| OQ-002 | What is the target minimum APY displayed to members? Or do we show only the current blended rate with no floor commitment? | Product | Open |
| OQ-003 | ~~How does the yield engine interact with the privacy layer?~~ **Resolved:** Share price appreciation requires no per-position knowledge. `totalAssets()` is public for solvency verification; individual `sharesBalance` values remain shielded inside `SavingsAccount`. | Protocol Architect | **Closed** |
| OQ-004 | Is 5% the right buffer rate? Too high reduces member APY; too low makes circles fragile under multiple simultaneous pauses. | Protocol Economist | Open |
| OQ-A | Does the YieldRouter mint ERC20-transferable shares or use purely internal accounting? If ERC20 (for composability with future features), `transfer()` and `transferFrom()` must be overridden to revert unless `msg.sender == savingsAccount`. Recommend internal-only for v1. | Smart Contract Lead | Open |
| OQ-B | How does the protocol handle an adapter exploit that causes `getBalance()` to collapse? All member share prices drop instantly. Is the 60% per-adapter allocation cap sufficient, or do we need an insurance fund / share price floor mechanism? | Protocol Architect | Open |
| OQ-C | Does the CircleBuffer also hold shares in the YieldRouter? **Resolved in AC-004-2:** Yes. The buffer deposits USDC into the YieldRouter, holds the resulting shares, and earns yield passively. No dilution occurs because the buffer earns proportionally to its share count. | Protocol Architect | **Closed** |
| OQ-D | Does `rebalance()` (moving capital between adapters) affect share price? It should not — `totalAssets()` remains constant during a rebalance (capital moves between adapters, not out of the pool). Confirm this in the implementation and add an invariant test. | Smart Contract Lead | Open |
| OQ-E | Adapter decimal normalisation: all `getBalance()` return values must be normalised to 6 decimals (USDC) before being summed in `totalAssets()`. This must be enforced in the `IYieldSourceAdapter` interface spec. | Smart Contract Lead | Open |
