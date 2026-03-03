# Interface Contract: IYieldRouter

**File:** `backend/contracts/interfaces/IYieldRouter.sol`
**Spec:** 004 — Yield Engine
**Solidity:** ^0.8.20
**Standard:** ERC4626 (access restricted — only SavingsAccount may call deposit/withdraw)

**v1 note:** Single adapter (Aave V3). `rebalance()`, `addAdapter()`, `removeAdapter()` deferred to v2.

---

## Functions

### ERC4626 (restricted)

| Signature | Caller | Description |
|---|---|---|
| `deposit(uint256 assets, address receiver) returns (uint256 shares)` | SavingsAccount only | Deposit USDC; mint shares to SavingsAccount; route to adapters |
| `withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)` | SavingsAccount only | Redeem shares; pull USDC from adapters; transfer to receiver |

### View

| Signature | Returns | Description |
|---|---|---|
| `totalAssets() returns (uint256)` | `uint256` | Sum of all adapter balances + idle USDC |
| `convertToShares(uint256 assets) returns (uint256)` | `uint256` | USDC → shares at current price |
| `convertToAssets(uint256 shares) returns (uint256)` | `uint256` | Shares → USDC at current price |
| `getBlendedAPY() returns (uint256)` | `uint256` | Current blended APY in basis points |
| `getCircuitBreakerStatus() returns (bool)` | `bool` | Whether rebalance circuit breaker is active |
| `getTotalAllocated() returns (uint256)` | `uint256` | Total USDC under management |

### Protocol-internal

| Signature | Caller | Description |
|---|---|---|
| `harvest()` | Anyone (permissionless) | Collect yield from AaveAdapter; deduct fee + buffer; share price rises |
| ~~`rebalance()`~~ | — | Deferred to v2 (single adapter, nothing to rebalance) |
| ~~`addAdapter()`~~ | — | Deferred to v2 (adapter registry) |
| ~~`removeAdapter()`~~ | — | Deferred to v2 |

---

## Events

| Event | Parameters |
|---|---|
| `CapitalAllocated` | `uint256 amount, uint256 timestamp` |
| `CapitalWithdrawn` | `uint256 amount, uint256 timestamp` |
| `YieldHarvested` | `uint256 grossYield, uint256 fee, uint256 bufferContribution, uint256 netYield, uint256 timestamp` |
| `CircuitBreakerTripped` | `string reason, uint256 timestamp` |
| `CircuitBreakerReset` | `uint256 timestamp` |
| `AdapterAdded` | `address indexed adapter, uint256 weightBps` |
| `AdapterRemoved` | `address indexed adapter` |

---

## Notes

- All monetary values in `uint256` (6 decimals — USDC)
- APY in basis points (10000 = 100%)
- `totalAssets()` is intentionally public — TVL is transparent for solvency verification
- `harvest()` fee: 10% of gross yield → treasury; buffer: 5% → CircleBuffer (held as shares)
- Circuit breaker (v1): checks Aave available liquidity; pauses `harvest()` only; deposits and withdrawals always available
- `getBlendedAPY()` returns Aave V3 USDC supply rate (read via AaveAdapter) — single source in v1
