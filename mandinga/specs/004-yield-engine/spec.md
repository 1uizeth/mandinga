# Spec 004 — Yield Engine

**Status:** Draft
**Version:** 0.4
**Date:** March 2026
**Depends on:** Spec 001 (Savings Account)

---

## Changelog

**v0.4 (March 2026):**
- **Yield source scoped to Aave V3 only for v1.** Real-world yield sources (Ondo OUSG, Superstate) require KYC legal structure out of scope for v1 — deferred to v2. See research.md Decision 10.
- **US-002 (Real-World Yield Sources) deferred to v2.** Replaced with single-source Aave V3 in v1.
- **US-003 (Oracle Integration) simplified.** No multi-source median required in v1 (single adapter). Circuit breaker reads Aave utilization/liquidity directly.
- **YieldRouter simplified.** No `allocationWeights`, no `rebalance()` in v1 (single adapter). Adapter pattern (`IYieldSourceAdapter`) retained so v2 can add adapters without changing YieldRouter interface.
- **OQ-001 closed.** Aave V3 only for v1.
- **OQ-D closed.** No `rebalance()` in v1.
- Updated architecture diagram to reflect single-adapter v1.

**v0.3 (February 2026):**
- CircleBuffer references to paused members removed. CircleBuffer sole purpose: yield smoothing only. Safety Net Pool handles round coverage.

**v0.2 (February 2026):**
- Added ERC4626 Meta-Vault architecture section — resolves OQ-003 and the Merkle-drop problem
- Updated `harvest()` model: fee + buffer deducted, net yield stays in pool, share price appreciates automatically — no per-position distribution required
- Updated CircleBuffer: now holds YieldRouter shares, earns yield passively (closes AC-004-4 ambiguity)
- Closed OQ-003 (privacy layer / yield interaction — resolved by share price model)
- Added OQ-A through OQ-E from architectural analysis with Luan

---

## Overview

The Yield Engine is the protocol component responsible for routing member deposits to yield-generating sources and returning yield to member positions. It operates automatically, requires no management by members, and is designed to continue functioning if any single yield source fails.

**The YieldRouter is ERC4626-compliant internally.** It acts as a vault routing yield through a single adapter (Aave V3 in v1). The `SavingsAccount` stores member positions as *shares* in the YieldRouter — not as raw USDC amounts. Yield accrues through share price appreciation: as the pool earns yield, `totalAssets()` grows and every share is worth more USDC. No per-position yield credits are ever needed, and no Merkle-drop is required.

**v1 yield source: Aave V3 only.** Multi-source routing (Ondo/Superstate real-world yield) is deferred to v2. The adapter pattern (`IYieldSourceAdapter`) is retained so v2 can add adapters without changing the YieldRouter interface.

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
       └── AaveAdapter    → Aave V3 Pool → aUSDC  (sole adapter in v1; OndoAdapter deferred to v2)
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
**I want** my deposited balance to automatically earn yield,
**So that** I benefit from competitive rates without managing anything.

**Acceptance Criteria:**
- AC-001-1: Deposits are allocated to Aave V3 within 1 block of confirmation (v1: single adapter)
- AC-001-2: **(v2)** Multi-source routing across at minimum 2 yield sources to prevent single-source dependency. Deferred — Aave V3 only in v1.
- AC-001-3: Allocation logic is deterministic and publicly auditable
- AC-001-4: The effective APY is shown to members in real time
- AC-001-5: No member action is required to begin earning yield — it is automatic on deposit

### US-002 · Real-World Yield Sources — Deferred to v2
**Status: Deferred.** Real-world yield sources (Ondo OUSG, Superstate, tokenised treasuries) require a KYC institutional relationship at the protocol layer. This legal structure is out of scope for v1. v1 yield source is Aave V3 only. This user story is preserved for v2 planning.

### US-003 · Oracle Integration — Simplified for v1
**As a** protocol,
**I want** yield rate data to be reliable and manipulation-resistant,
**So that** the protocol cannot be exploited through bad rate data.

**Acceptance Criteria:**
- AC-003-1: v1 uses Aave's native liquidity/utilisation data directly — no external oracle required for the single adapter
- AC-003-2: **(v2)** Multi-source oracle median for multi-adapter routing. Deferred.
- AC-003-3: Circuit breaker: if Aave's reported APY deviates unexpectedly (> 50% drop in single harvest), rebalancing is paused pending governance review. Withdrawals are never paused.
- AC-003-4: The circuit breaker does not pause withdrawals — members can always exit

### US-004 · Yield Reserve for Circle Buffer
**As a** circle participant,
**I need** yield reporting to be stable across harvest cycles,
**So that** short-term yield variance does not create a confusing or misleading APY display.

**Note:** The CircleBuffer no longer handles missed round contributions or member defaults. That function is now owned by the Safety Net Pool (Spec 003). The CircleBuffer's sole remaining purpose is yield smoothing — absorbing harvest variance to present members with a stable reported APY.

**Acceptance Criteria:**
- AC-004-1: 5% of gross yield (configurable by governance) is directed to the `CircleBuffer` contract at each `harvest()`
- AC-004-2: The `CircleBuffer` deposits received USDC into the YieldRouter and holds the resulting **shares** — it earns yield passively via share price appreciation while idle
- AC-004-3: The buffer is protocol-global (not circle-specific) — its only role is smoothing reported yield, not covering per-circle obligations
- AC-004-4: In a harvest cycle where yield is below the trailing average, the buffer supplements the reported APY to reduce visible variance. In a cycle where yield exceeds the trailing average, the excess is directed to the buffer.
- AC-004-5: The buffer does not cover missed round contributions — that is entirely the Safety Net Pool's responsibility (Spec 003 US-004).

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
| OQ-001 | ~~Which real-world yield product?~~ **Resolved:** Aave V3 only for v1. Ondo/Superstate deferred to v2 pending legal/KYC structure. | Legal / Architect | **Closed** |
| OQ-002 | What is the target minimum APY displayed to members? Or do we show only the current blended rate with no floor commitment? | Product | Open |
| OQ-003 | ~~How does the yield engine interact with the privacy layer?~~ **Resolved:** Share price appreciation requires no per-position knowledge. `totalAssets()` is public for solvency verification; individual `sharesBalance` values remain shielded inside `SavingsAccount`. | Protocol Architect | **Closed** |
| OQ-004 | Is 5% the right buffer rate for yield smoothing? Too high reduces member net APY; too low means the buffer cannot absorb meaningful harvest variance. The right rate is now decoupled from circle continuity concerns (that is the Safety Net Pool's problem) — it is purely a yield-display quality tradeoff. | Protocol Economist | Open |
| OQ-A | Does the YieldRouter mint ERC20-transferable shares or use purely internal accounting? If ERC20 (for composability with future features), `transfer()` and `transferFrom()` must be overridden to revert unless `msg.sender == savingsAccount`. Recommend internal-only for v1. | Smart Contract Lead | Open |
| OQ-B | How does the protocol handle an adapter exploit that causes `getBalance()` to collapse? All member share prices drop instantly. Is the 60% per-adapter allocation cap sufficient, or do we need an insurance fund / share price floor mechanism? | Protocol Architect | Open |
| OQ-C | Does the CircleBuffer also hold shares in the YieldRouter? **Resolved in AC-004-2:** Yes. The buffer deposits USDC into the YieldRouter, holds the resulting shares, and earns yield passively. No dilution occurs because the buffer earns proportionally to its share count. | Protocol Architect | **Closed** |
| OQ-D | ~~Does `rebalance()` affect share price?~~ **Resolved:** No `rebalance()` in v1 (single Aave adapter). Deferred to v2 when multi-adapter routing is added. | Smart Contract Lead | **Closed** |
| OQ-E | Adapter decimal normalisation: all `getBalance()` return values must be normalised to 6 decimals (USDC) before being summed in `totalAssets()`. This must be enforced in the `IYieldSourceAdapter` interface spec. | Smart Contract Lead | Open |
