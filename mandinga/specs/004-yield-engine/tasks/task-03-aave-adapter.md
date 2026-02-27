# Task 004-03 — Implement AaveAdapter

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Ready — **primary yield source in v1**
**Estimated effort:** 6 hours
**Dependencies:** Task 004-01 (IYieldRouter interface)
**Parallel-safe:** Yes

---

## Objective

Implement `AaveAdapter.sol` — a yield source adapter that deposits USDC into Aave V3, earns interest via aTokens, and exposes the `IYieldSourceAdapter` interface consumed by `YieldRouter`.

---

## Context

Aave V3 is the primary DeFi yield source for Mandinga Protocol. The adapter wraps Aave's pool interface to present a uniform interface to the YieldRouter, handling the aToken mechanics internally.

See: Spec 004, US-002 (Real-World Yield Sources), US-001 (Automatic Yield Routing).

---

## Acceptance Criteria

- [ ] Interface `IYieldSourceAdapter` defined at `backend/contracts/interfaces/IYieldSourceAdapter.sol`:
  - `deposit(uint256 amount)` — deposit USDC into this yield source
  - `withdraw(uint256 amount)` — withdraw from this yield source
  - `getBalance() returns (uint256)` — current balance (6 decimals, USDC) including accrued yield
  - `getAPY() returns (uint256)` — current APY in basis points
  - `getAsset() returns (address)` — the underlying asset (USDC)
  - `harvest() returns (uint256 yieldAmount)` — collect and return yield earned since last harvest
- [ ] `AaveAdapter.sol` contract at `backend/contracts/yield/AaveAdapter.sol` implementing `IYieldSourceAdapter`:
  - Integrates with Aave V3 `IPool` and `IPoolDataProvider`
  - Deposits USDC and receives aUSDC
  - `harvest()` calculates yield as `aUSDC.balanceOf(this) - lastRecordedBalance` and transfers yield to YieldRouter
  - Updates `lastRecordedBalance` after every deposit, withdrawal, and harvest
  - `getAPY()` reads Aave V3 `IPoolDataProvider.getReserveData(USDC).currentLiquidityRate` — no external oracle needed
- [ ] Unit tests at `backend/test/unit/AaveAdapter.t.sol` using Foundry's `vm.createFork()` against Arbitrum mainnet:
  - Deposit 1000 USDC → verify aUSDC balance increases
  - `vm.roll(block.number + 1000)` → harvest → verify yield amount > 0
  - Withdraw 500 USDC → verify USDC returned, aUSDC balance decreases
  - `getAPY()` returns a non-zero value matching Aave's current USDC supply rate
- [ ] All tests passing against Arbitrum fork (`forge test --fork-url $ARBITRUM_RPC_URL`)

---

## Output Files

- `backend/contracts/interfaces/IYieldSourceAdapter.sol`
- `backend/contracts/yield/AaveAdapter.sol`
- `backend/test/unit/AaveAdapter.t.sol`

---

## Notes

- Use Aave's `IPool.supply()` and `IPool.withdraw()` — not the deprecated `deposit()`
- The adapter must `approve` Aave's pool contract before calling `supply()`
- `harvest()` must be idempotent — calling it twice in the same block should return 0 on the second call
- Test with Foundry fork: `forge test --fork-url $ARBITRUM_RPC_URL --fork-block-number <recent block>`; Aave V3 is live on Arbitrum
- `getBalance()` must return values in 6 decimals (USDC precision) — normalise if aToken uses different decimals
- **This is the sole yield adapter in v1.** YieldRouter routes 100% of deposits to this adapter.
