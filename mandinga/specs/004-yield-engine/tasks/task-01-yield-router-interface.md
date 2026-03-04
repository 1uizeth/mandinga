# Task 004-01 — Define IYieldRouter Interface

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Ready
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

- [ ] Interface file created at `backend/contracts/interfaces/IYieldRouter.sol`
- [ ] `IYieldRouter` extends ERC4626 (`IERC4626`) — do not redefine `deposit()` or `withdraw()`; they are inherited. Add the following protocol-specific functions:
  - `harvest()` — collect yield from all adapters and let it accrue via share price appreciation
  - `getBlendedAPY() returns (uint256)` — current blended rate in basis points
  - `getCircuitBreakerStatus() returns (bool)` — whether circuit breaker is active
  - `getTotalAllocated() returns (uint256)` — total capital under management (mirrors `totalAssets()`)
- [ ] NatSpec documentation on every function explaining inputs, outputs, and revert conditions
- [ ] Interface emits the following events:
  - `CapitalAllocated(uint256 amount, uint256 timestamp)`
  - `CapitalWithdrawn(uint256 amount, uint256 timestamp)`
  - `YieldHarvested(uint256 grossYield, uint256 protocolFee, uint256 bufferContribution, uint256 netYield, uint256 timestamp)`
  - `CircuitBreakerTripped(string reason, uint256 timestamp)` — emitted for logging when the circuit breaker activates
  - `CircuitBreakerReset(uint256 timestamp)`
- [ ] Interface declares the following custom errors:
  - `error CircuitBreakerActive()` — used to revert deposit/harvest calls while circuit breaker is engaged (distinct from the `CircuitBreakerTripped` event)
- [ ] Interface compiles successfully with `forge build`
- [ ] Interface `IYieldSourceAdapter` defined at `backend/contracts/interfaces/IYieldSourceAdapter.sol`:
  - `deposit(uint256 amount)` — deposit USDC into the yield source
  - `withdraw(uint256 amount)` — withdraw USDC from the yield source (reverts if PSM liquidity insufficient)
  - `withdrawMax(uint256 requested) returns (uint256 withdrawn)` — partial withdrawal fallback; emits `PartialWithdrawal`
  - `getBalance() returns (uint256)` — current USDC balance including accrued yield (6 decimals)
  - `getAPY() returns (uint256)` — current APY in basis points
  - `getAsset() returns (address)` — the underlying asset (USDC)
  - `harvest() returns (uint256 yieldAmount)` — collect and return yield earned since last harvest
  - NatSpec on every function

---

## Output Files

- `backend/contracts/interfaces/IYieldRouter.sol`
- `backend/contracts/interfaces/IYieldSourceAdapter.sol`

---

## Notes

- Use `uint256` for all monetary values (no `int` — we never have negative balances)
- APY is returned in basis points (10000 = 100%) to avoid floating point
- Do not include governance functions in this interface — those belong to an admin interface
