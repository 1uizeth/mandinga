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

The yield router abstracts yield source allocation away from the savings account. The savings account deposits capital to the router and receives yield credits — it doesn't care whether yield comes from Aave or Ondo. The interface defines this boundary.

See: `plan.md` §3.4 for the key function signatures.

---

## Acceptance Criteria

- [ ] Interface file created at `contracts/interfaces/IYieldRouter.sol`
- [ ] Interface includes:
  - `allocate(uint256 amount)` — deposit capital for yield routing
  - `withdraw(uint256 amount)` — withdraw capital (for member withdrawals)
  - `harvest()` — collect and credit accrued yield to positions
  - `getBlendedAPY() returns (uint256)` — current blended rate in basis points
  - `getCircuitBreakerStatus() returns (bool)` — whether circuit breaker is active
  - `getTotalAllocated() returns (uint256)` — total capital under management
- [ ] NatSpec documentation on every function explaining inputs, outputs, and revert conditions
- [ ] Interface emits the following events:
  - `CapitalAllocated(uint256 amount, uint256 timestamp)`
  - `YieldHarvested(uint256 amount, uint256 timestamp)`
  - `CircuitBreakerTripped(string reason, uint256 timestamp)`
  - `CircuitBreakerReset(uint256 timestamp)`
- [ ] Interface compiled successfully with `solc ^0.8.20`

---

## Output Files

- `contracts/interfaces/IYieldRouter.sol`

---

## Notes

- Use `uint256` for all monetary values (no `int` — we never have negative balances)
- APY is returned in basis points (10000 = 100%) to avoid floating point
- Do not include governance functions in this interface — those belong to an admin interface
