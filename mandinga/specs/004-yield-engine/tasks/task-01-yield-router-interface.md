# Task 004-01 — Define IYieldRouter Interface

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Done ✓
**Estimated effort:** 2 hours
**Dependencies:** None
**Parallel-safe:** Yes (no dependencies)

---

## Objective

Define the `IYieldRouter` Solidity interface. This is the contract boundary that all yield adapter implementations must satisfy, and that `SavingsAccount` uses to interact with the yield system. Getting this interface right before any implementation saves significant refactoring later.

---

## Context

The yield router abstracts yield source allocation away from the savings account. The savings account deposits capital to the router and receives yield — it doesn't care which adapter is active. The interface defines this boundary. v1 adapter: `SparkUsdcVaultAdapter` (Sky Savings Rate on Base).

See: Spec 004 v0.5.

---

## Acceptance Criteria

- [x] Interface file created at `contracts/src/interfaces/IYieldRouter.sol`
- [x] `IYieldRouter` extends ERC4626 (`IERC4626`) — `deposit()`, `withdraw()`, `mint()`, `redeem()` inherited. Protocol-specific additions:
  - `allocate(uint256 amount)` — SavingsAccount entry point (restricted)
  - `harvest()` — collects yield; share price appreciation model
  - `getBlendedAPY() returns (uint256)` — delegates to sparkAdapter
  - `getCircuitBreakerStatus() returns (bool)` — reflects `circuitBreakerTripped` flag
  - `getTotalAllocated() returns (uint256)` — mirrors `totalAssets()`
- [x] NatSpec on every function ✓
- [x] Events: `CapitalAllocated`, `CapitalWithdrawn`, `YieldHarvested`, `CircuitBreakerTripped`, `CircuitBreakerReset` ✓
- [x] Error: `CircuitBreakerActive()` ✓
- [x] Interface compiles successfully with `forge build` ✓
- [x] `IYieldSourceAdapter` at `contracts/src/interfaces/IYieldSourceAdapter.sol`:
  - `deposit`, `withdraw`, `withdrawMax`, `getBalance`, `getAPY`, `getAsset`, `harvest` ✓
  - Event `PartialWithdrawal` ✓
  - NatSpec on every function ✓

---

## Output Files

- `contracts/src/interfaces/IYieldRouter.sol`
- `contracts/src/interfaces/IYieldSourceAdapter.sol`

---

## Notes

- Use `uint256` for all monetary values (no `int` — we never have negative balances)
- APY is returned in basis points (10000 = 100%) to avoid floating point
- Do not include governance functions in this interface — those belong to an admin interface
