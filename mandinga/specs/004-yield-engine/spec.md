# Spec 004 — Yield Engine

**Status:** Draft
**Version:** 0.4
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account)

---

## Changelog

**v0.4 (February 2026):**
- **Yield source scoped to Aave V3 only for v1.** `OndoAdapter` (real-world yield) and `OracleAggregator` deferred to v2. Rationale: real-world yield sources require KYC legal structure out of scope for v1. See research.md Decision 10.
- **US-002 (Real-World Yield Sources) deferred to v2.**
- **US-003 (Oracle Integration) simplified:** no multi-source median; circuit breaker reads Aave utilization/liquidity directly.
- **US-001 AC-001-2 updated:** single yield source (Aave V3) in v1; multi-source requirement deferred to v2.
- **OQ-001 closed:** Aave V3 only for v1.
- **OQ-D closed:** no `rebalance()` function in v1 (single adapter).
- **YieldRouter simplified:** no `allocationWeights`, no `rebalance()`, direct deposit to AaveAdapter.

**v0.3 (February 2026):**
- **Updated US-004 (CircleBuffer):** removed stale references to "paused members" and "grace period" — these mechanics were eliminated in Spec 002 v0.3. The CircleBuffer's sole remaining purpose is **yield smoothing**: absorbing yield variance across harvest cycles so members experience a stable reported APY. Round coverage (covering missed `D` contributions mid-circle) is now handled entirely by the Solidarity Pool (Spec 003) — the CircleBuffer plays no role in it.
- Updated OQ-004: rephrased to reflect yield-smoothing-only purpose.

**v0.2 (February 2026):**
- Added ERC4626 Meta-Vault architecture section — resolves OQ-003 and the Merkle-drop problem
- Updated `harvest()` model: fee + buffer deducted, net yield stays in pool, share price appreciates automatically — no per-position distribution required
- Updated CircleBuffer: now holds YieldRouter shares, earns yield passively (closes AC-004-4 ambiguity)
- Closed OQ-003 (privacy layer / yield interaction — resolved by share price model)
- Added OQ-A through OQ-E from architectural analysis with Luan

---

## Overview

The Yield Engine is the protocol component responsible for routing member deposits to yield-generating sources and returning yield to member positions. It operates automatically, requires no management by members, and is designed to continue functioning if any single yield source fails.

**The YieldRouter is ERC4626-compliant internally.** It acts as a meta-vault routing yield through a single adapter (Aave V3 in v1). The `SavingsAccount` stores member positions as *shares* in the YieldRouter — not as raw USDC amounts. Yield accrues through share price appreciation: as the pool earns yield, `totalAssets()` grows and every share is worth more USDC. No per-position yield credits are ever needed, and no Merkle-drop is required.

**v1 yield source: Aave V3 only.** Multi-source routing (Ondo/Superstate) is deferred to v2. The adapter pattern (`IYieldSourceAdapter`) is retained so v2 can add adapters without changing the YieldRouter interface.

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
       └── AaveAdapter    → Aave V3 Pool → aUSDC  (sole adapter in v1)
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
- AC-001-1: Deposits are routed to the yield source (Aave V3) within 1 block of confirmation
- AC-001-2: ~~At minimum 2 yield sources~~ **v1: single yield source (Aave V3)**. Multi-source routing deferred to v2. The adapter interface (`IYieldSourceAdapter`) is retained so v2 can add sources without interface changes.
- AC-001-3: Allocation logic is deterministic and publicly auditable
- AC-001-4: The effective APY (Aave V3 USDC supply rate) is shown to members in real time
- AC-001-5: No member action is required to begin earning yield — it is automatic on deposit

### US-002 · Real-World Yield Sources — **Deferred to v2**

**Status:** Deferred. Real-world yield (Ondo OUSG, Superstate) requires a KYC relationship at the protocol entity level and associated legal structure work. This is out of scope for v1.

**v1 yield source:** Aave V3 USDC supply — DeFi-native, permissionless, no KYC.

**v2 target:** Add `OndoAdapter` or equivalent once legal and compliance structure is in place. The `IYieldSourceAdapter` interface and YieldRouter adapter registry are designed to accommodate new sources without breaking the ERC4626 surface.

_(Original acceptance criteria preserved below for v2 reference)_

- ~~AC-002-1: Tokenised money market fund integration (Ondo OUSG, Superstate)~~ → v2
- ~~AC-002-2: KYC abstracted at protocol layer~~ → v2
- ~~AC-002-3: DeFi fallback (Aave/Compound)~~ → v1 has Aave only, this is the primary source
- ~~AC-002-4: Configurable allocation ratio real-world/DeFi~~ → v2
- AC-002-5: Identity of all active yield sources publicly disclosed on-chain → **retained for v1** (Aave V3 pool address publicly visible)

### US-003 · Oracle / Circuit Breaker — Simplified for v1

**Context:** With a single yield source (Aave V3), multi-source oracle aggregation (`OracleAggregator`) is not needed. v1 reads the Aave USDC supply rate directly from Aave's `IPoolDataProvider`. The circuit breaker monitors Aave's available liquidity.

**Acceptance Criteria:**
- AC-003-1: Current APY is read directly from Aave V3 `IPoolDataProvider.getReserveData()` — no external oracle required for v1
- AC-003-2: ~~Minimum 2 independent oracle sources~~ → deferred to v2 (multi-source context)
- AC-003-3: If Aave data is stale or unavailable, display the last known APY with a "stale" indicator; do not block deposits or withdrawals
- AC-003-4: Circuit breaker: if Aave's available USDC liquidity falls below a configurable threshold (governance-set, default: sufficient for 10% of TVL withdrawal in one transaction), `harvest()` is paused until liquidity recovers; deposits and withdrawals remain available
- AC-003-5: The circuit breaker **never** pauses withdrawals — members can always exit

### US-004 · Yield Reserve for Circle Buffer
**As a** circle participant,
**I need** yield reporting to be stable across harvest cycles,
**So that** short-term yield variance does not create a confusing or misleading APY display.

**Note:** The CircleBuffer no longer handles missed round contributions or member defaults. That function is now owned by the Solidarity Pool (Spec 003). The CircleBuffer's sole remaining purpose is yield smoothing — absorbing harvest variance to present members with a stable reported APY.

**Acceptance Criteria:**
- AC-004-1: 5% of gross yield (configurable by governance) is directed to the `CircleBuffer` contract at each `harvest()`
- AC-004-2: The `CircleBuffer` deposits received USDC into the YieldRouter and holds the resulting **shares** — it earns yield passively via share price appreciation while idle
- AC-004-3: The buffer is protocol-global (not circle-specific) — its only role is smoothing reported yield, not covering per-circle obligations
- AC-004-4: In a harvest cycle where yield is below the trailing average, the buffer supplements the reported APY to reduce visible variance. In a cycle where yield exceeds the trailing average, the excess is directed to the buffer.
- AC-004-5: The buffer does not cover missed round contributions — that is entirely the Solidarity Pool's responsibility (Spec 003 US-004).

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
- Real-world yield sources (Ondo/Superstate) — deferred to v2
- Multi-source oracle aggregation (`OracleAggregator`) — deferred to v2
- `rebalance()` function — not needed with single adapter in v1

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Which real-world yield product do we integrate with first? | Legal / Architect | **Resolved — Deferred to v2.** v1 uses Aave V3 only. |
| OQ-002 | What is the target minimum APY displayed to members? | Product | Open |
| OQ-003 | ~~How does the yield engine interact with the privacy layer?~~ **Resolved:** Share price appreciation requires no per-position knowledge. | Protocol Architect | **Closed** |
| OQ-004 | Is 5% the right buffer rate for yield smoothing? | Protocol Economist | Open |
| OQ-A | Does the YieldRouter mint ERC20-transferable shares or use purely internal accounting? Recommend internal-only for v1. | Smart Contract Lead | Open |
| OQ-B | How does the protocol handle an Aave exploit that causes `getBalance()` to collapse? Single adapter means full exposure — no allocation cap mitigates this in v1. Does the protocol need a share price floor mechanism? | Protocol Architect | Open |
| OQ-C | Does the CircleBuffer also hold shares in the YieldRouter? **Resolved in AC-004-2:** Yes. | Protocol Architect | **Closed** |
| OQ-D | Does `rebalance()` affect share price? | Smart Contract Lead | **Resolved — Closed.** `rebalance()` removed from v1 (single adapter). |
| OQ-E | Adapter decimal normalisation: `getBalance()` must return 6 decimals (USDC). Enforced in `IYieldSourceAdapter`. | Smart Contract Lead | Open |
