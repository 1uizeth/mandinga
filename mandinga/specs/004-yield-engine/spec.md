# Spec 004 — Yield Engine

**Status:** Draft
**Version:** 0.4
**Date:** March 2026
**Depends on:** Spec 001 (Savings Account)

---

## Changelog

**v0.5 (March 2026):**
- **Yield source changed from Aave V3 to Spark USDC Vault (Sky Savings Rate).** `SparkUsdcVaultAdapter` replaces `AaveAdapter` as the sole v1 adapter. USDC is deposited into `UsdcVaultL2` (UUPS ERC4626, Base), swapped to sUSDS via PSM3, and yield accrues through `rateProvider.getConversionRate()` appreciation.
- **Chain confirmed: Base.** Testnet target: Base Sepolia (`UsdcVaultL2` proxy `0x4d5158F47E489a60bCaA8CD8F06B14A143E4043D`). Aligns with Spec 006 CRE workflow chain.
- **AaveAdapter removed from v1 scope.** `AaveAdapter.sol` and `task-03-aave-adapter.md` superseded by `SparkUsdcVaultAdapter`.
- **OQ-E resolved.** Decimal normalisation handled by `UsdcVaultL2.convertToAssets()` — always returns USDC (6 dec); adapter `getBalance()` does not require custom normalisation.
- **New edge case documented:** PSM pocket USDC liquidity cap limits `maxWithdraw`; adapter must check `vault.maxWithdraw(address(this))` before large withdrawals. Escape hatch `vault.exit()` available if PSM is unavailable.

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

**The YieldRouter is ERC4626-compliant internally.** It acts as a vault routing yield through a single adapter (Spark USDC Vault — Sky Savings Rate via PSM3/sUSDS — in v1). The `SavingsAccount` stores member positions as *shares* in the YieldRouter — not as raw USDC amounts. Yield accrues through share price appreciation: as the pool earns yield, `totalAssets()` grows and every share is worth more USDC. No per-position yield credits are ever needed, and no Merkle-drop is required.

**v1 yield source: Spark USDC Vault (Sky Savings Rate) only.** USDC is deposited into Sky Protocol's PSM3, converted to sUSDS, and yield is earned via the Sky Savings Rate. Multi-source routing (Ondo/Superstate real-world yield) is deferred to v2. The adapter pattern (`IYieldSourceAdapter`) is retained so v2 can add adapters without changing the YieldRouter interface. *(Previously Aave V3 — replaced per Clarification Session 2026-03-04.)*

The yield engine is a background infrastructure layer. Members never interact with it directly — they see only its output: their current APY and USDC-equivalent balance in their Savings Account dashboard.

---

## Clarifications

### Session 2026-03-04

- Q: Which Spark product is used as the v1 yield source? → A: Sky Savings Rate — USDC deposited into PSM3, converted to sUSDS, yield from Sky Savings Rate (SparkUsdcVaultAdapter)
- Q: Which chain does SparkUsdcVaultAdapter target? → A: Base (testnet: Base Sepolia; proxy `0x4d5158F47E489a60bCaA8CD8F06B14A143E4043D` — confirmed by UsdcVaultL2 integration guide)
- Q: Is UsdcVaultL2 fully ERC4626 compliant? → A: Yes — UUPS-upgradeable ERC4626; asset = USDC (6 dec), reserve = sUSDS (18 dec), shares = sUSDC (18 dec); 1e12 decimal scaling handled by PSM math internally; yield accrues as increasing `rateProvider.getConversionRate()` (no rebase)
- Q: How should AaveAdapter be handled? → A: Delete entirely — `AaveAdapter.sol` and `task-03-aave-adapter.md` removed; no production deployment existed; adapter pattern in `IYieldSourceAdapter` preserves v2 extensibility without retaining dead code

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
       └── SparkUsdcVaultAdapter → Sky PSM3 → sUSDS  (sole adapter in v1; OndoAdapter deferred to v2)
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

### SparkUsdcVaultAdapter — Integration Contract

`SparkUsdcVaultAdapter` wraps `UsdcVaultL2` (Sky Savings Rate ERC4626 on Base) to implement `IYieldSourceAdapter`. All interactions go through the **proxy** address (permanent; implementation may be upgraded by Sky governance).

**Contract addresses (Base Sepolia testnet):**

| Contract | Address |
|---|---|
| UsdcVaultL2 Proxy | `0x4d5158F47E489a60bCaA8CD8F06B14A143E4043D` |
| MockUSDC | `0x996C4ae5897bE0c1D89F4AD857d64F403b11bFb2` |
| MockSUSDS | `0x1339Ad362bAc438e885f535966127Ae03fC09002` |
| MockRateProvider | `0xaCa48d64e88E9812BdCCa1F156418E25Fd6C656D` |
| MockPSM | `0x8E1913834955E004c342a00cc38C3dFF53FCc46e` |

**Token flow:**
```
YieldRouter --[USDC 6 dec]--> SparkUsdcVaultAdapter
                                    │
                                    ├─ USDC.approve(vault, amount)
                                    ├─ vault.deposit(amount, address(this))  ← PSM swaps USDC→sUSDS
                                    └─ holds sUSDC shares (18 dec)
                                    │
                             yield accrues via rateProvider.getConversionRate() growth
                                    │
                                    └─ vault.withdraw(yieldDelta, yieldRouter, address(this))
```

**`IYieldSourceAdapter` method mapping:**

| Method | Implementation |
|---|---|
| `deposit(uint256 amount)` | `USDC.approve(vault, amount)` then `vault.deposit(amount, address(this))` |
| `withdraw(uint256 amount)` | Check `vault.maxWithdraw(address(this)) >= amount` first; then `vault.withdraw(amount, yieldRouter, address(this))` |
| `getBalance() → uint256` | `vault.convertToAssets(vault.balanceOf(address(this)))` — returns USDC (6 dec); no custom normalisation needed |
| `getAPY() → uint256` | Computed from `rateProvider.getConversionRate()` delta between harvest windows; expressed in basis points |
| `harvest() → uint256 yieldAmount` | `currentBalance = getBalance()`, `yieldAmount = currentBalance - lastRecordedBalance`, call `vault.withdraw(yieldAmount, yieldRouter, address(this))`, update `lastRecordedBalance` |

**Decimal handling:** `UsdcVaultL2` internally manages the 6↔18 decimal mismatch (USDC vs sUSDS/sUSDC) via PSM swap math. `getBalance()` always returns a 6-decimal USDC amount via `convertToAssets()` — no adapter-level normalisation required. This resolves OQ-E.

**Liquidity cap constraint:** `vault.maxWithdraw(address(this))` is capped by USDC liquidity in the PSM pocket. The adapter must check this before any withdrawal and must not revert the YieldRouter if the PSM is temporarily illiquid — instead, it should withdraw the maximum available and emit a `PartialWithdrawal` event.

**Escape hatch:** If the PSM becomes permanently unavailable, `vault.exit(shares, receiver, address(this))` transfers raw **sUSDS** directly to `receiver`, bypassing the PSM swap. This path should only be triggered by governance emergency action.

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
- AC-001-1: Deposits are routed to the Spark USDC Vault (`UsdcVaultL2` on Base) within 1 block of confirmation (v1: single adapter)
- AC-001-2: **(v2)** Multi-source routing across at minimum 2 yield sources to prevent single-source dependency. Deferred — Spark USDC Vault only in v1.
- AC-001-3: Allocation logic is deterministic and publicly auditable
- AC-001-4: The effective APY is shown to members in real time
- AC-001-5: No member action is required to begin earning yield — it is automatic on deposit

### US-002 · Real-World Yield Sources — Deferred to v2
**Status: Deferred.** Real-world yield sources (Ondo OUSG, Superstate, tokenised treasuries) require a KYC institutional relationship at the protocol layer. This legal structure is out of scope for v1. v1 yield source is the Spark USDC Vault (Sky Savings Rate on Base). This user story is preserved for v2 planning.

### US-003 · Oracle Integration — Simplified for v1
**As a** protocol,
**I want** yield rate data to be reliable and manipulation-resistant,
**So that** the protocol cannot be exploited through bad rate data.

**Acceptance Criteria:**
- AC-003-1: v1 reads `rateProvider.getConversionRate()` (via `UsdcVaultL2`) to derive the current APY — no external oracle required for the single adapter
- AC-003-2: **(v2)** Multi-source oracle median for multi-adapter routing. Deferred.
- AC-003-3: Circuit breaker: if the vault's conversion rate drops unexpectedly (> 50% drop relative to previous harvest), new deposits are paused pending governance review. Withdrawals are never paused.
- AC-003-4: The circuit breaker does not pause withdrawals — members can always exit (including via `vault.exit()` escape hatch if PSM is unavailable)

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

## Edge Cases & Failure Handling

### PSM Liquidity Cap
`UsdcVaultL2.maxWithdraw(address(adapter))` is bounded by the USDC liquidity available in the PSM pocket. If a withdrawal request exceeds this cap:
- The adapter must call `vault.maxWithdraw(address(this))` before any `withdraw()` call.
- If `maxWithdraw < requested`, the adapter withdraws the maximum available and emits a `PartialWithdrawal(requested, actual)` event.
- Remaining yield is automatically recaptured in the next `harvest()` cycle via the `lastRecordedBalance` delta mechanism.
- Governance may trigger an emergency `vault.exit()` (transfers raw sUSDS) if the PSM is persistently illiquid.

### PSM Unavailability / Escape Hatch
If Sky Protocol's PSM becomes permanently unavailable (depeg, exploit, governance halt):
- `vault.exit(shares, receiver, address(this))` bypasses the PSM swap and transfers raw **sUSDS** directly to `receiver`.
- This path must only be callable by the YieldRouter owner (governance multisig) via an `emergencyExit()` function on the adapter.
- The adapter must emit `EmergencyExit(sharesRedeemed, susdsReceived, receiver)`.
- After exit, the adapter is deregistered from the YieldRouter and the protocol enters a withdrawal-only mode until a replacement adapter is registered.

### Vault Upgrade (UUPS)
`UsdcVaultL2` is UUPS-upgradeable by Sky governance. The proxy address is permanent. The adapter stores only the proxy address and is unaffected by implementation upgrades. If an upgrade changes the `IVault` interface, `SparkUsdcVaultAdapter` must be redeployed and re-registered.

### Rate Provider Rate Drop (Circuit Breaker)
If `rateProvider.getConversionRate()` at harvest time is more than 50% lower than the previous harvest rate:
- `SparkUsdcVaultAdapter.harvest()` reverts with `CircuitBreakerTripped()`.
- New deposits via `_routeToAdapters()` are paused on the YieldRouter.
- Withdrawals are never blocked.

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
| OQ-001 | ~~Which real-world yield product?~~ **Resolved (updated v0.5):** Spark USDC Vault (Sky Savings Rate via PSM3/sUSDS, `UsdcVaultL2` on Base) for v1. Aave V3 removed. Ondo/Superstate deferred to v2. | Legal / Architect | **Closed** |
| OQ-002 | What is the target minimum APY displayed to members? Or do we show only the current blended rate with no floor commitment? | Product | Open |
| OQ-003 | ~~How does the yield engine interact with the privacy layer?~~ **Resolved:** Share price appreciation requires no per-position knowledge. `totalAssets()` is public for solvency verification; individual `sharesBalance` values remain shielded inside `SavingsAccount`. | Protocol Architect | **Closed** |
| OQ-004 | Is 5% the right buffer rate for yield smoothing? Too high reduces member net APY; too low means the buffer cannot absorb meaningful harvest variance. The right rate is now decoupled from circle continuity concerns (that is the Safety Net Pool's problem) — it is purely a yield-display quality tradeoff. | Protocol Economist | Open |
| OQ-A | Does the YieldRouter mint ERC20-transferable shares or use purely internal accounting? If ERC20 (for composability with future features), `transfer()` and `transferFrom()` must be overridden to revert unless `msg.sender == savingsAccount`. Recommend internal-only for v1. | Smart Contract Lead | Open |
| OQ-B | How does the protocol handle an adapter exploit that causes `getBalance()` to collapse? All member share prices drop instantly. Is the 60% per-adapter allocation cap sufficient, or do we need an insurance fund / share price floor mechanism? | Protocol Architect | Open |
| OQ-C | Does the CircleBuffer also hold shares in the YieldRouter? **Resolved in AC-004-2:** Yes. The buffer deposits USDC into the YieldRouter, holds the resulting shares, and earns yield passively. No dilution occurs because the buffer earns proportionally to its share count. | Protocol Architect | **Closed** |
| OQ-D | ~~Does `rebalance()` affect share price?~~ **Resolved:** No `rebalance()` in v1 (single Spark USDC Vault adapter). Deferred to v2 when multi-adapter routing is added. | Smart Contract Lead | **Closed** |
| OQ-E | ~~Adapter decimal normalisation.~~ **Resolved (v0.5):** `UsdcVaultL2.convertToAssets()` always returns USDC (6 dec) by handling the 1e12 sUSDS/sUSDC decimal mismatch internally via PSM math. `SparkUsdcVaultAdapter.getBalance()` calls `convertToAssets(balanceOf(this))` and returns 6-decimal USDC — no adapter-level normalisation required. The `IYieldSourceAdapter` interface must still specify "return value in 6 decimals (USDC)" as a contract for all future adapters. | Smart Contract Lead | **Closed** |
| OQ-F | PSM liquidity cap: `vault.maxWithdraw(adapter)` is capped by live USDC in the PSM pocket. Should partial withdrawal on a liquidity-constrained harvest trigger a `PartialWithdrawal` event and defer the remainder, or should it revert and retry on the next harvest cycle? | Smart Contract Lead | Open |
