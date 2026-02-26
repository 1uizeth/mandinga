# Task 004-04 — Implement YieldRouter

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Blocked on Tasks 004-02 and 004-03
**Estimated effort:** 8 hours
**Dependencies:** Task 004-01 (interface), Task 004-02 (OracleAggregator), Task 004-03 (AaveAdapter)
**Parallel-safe:** No

---

## Objective

Implement `YieldRouter.sol` — the central yield orchestration contract. It manages capital allocation across multiple yield source adapters, harvests yield, credits it to the SavingsAccount, collects the protocol fee, and maintains the circle buffer reserve.

---

## Context

This is the contract that makes the savings account yield-bearing. It receives deposits from `SavingsAccount`, allocates them to adapters (Aave, Ondo), harvests yield periodically, and routes the net yield (after protocol fee) back to member balances via `SavingsAccount.creditYield`.

See: Spec 004 all user stories, plan.md §3.4.

---

## Acceptance Criteria

### Allocation
- [ ] `allocate(uint256 amount)` — called by SavingsAccount on deposit:
  - Receives USDC from SavingsAccount
  - Splits allocation across active adapters per `allocationWeights`
  - Calls `adapter.deposit(allocatedAmount)` for each adapter
  - Emits `CapitalAllocated(amount, timestamp)`
- [ ] `withdraw(uint256 amount)` — called by SavingsAccount on withdrawal:
  - Retrieves USDC from adapters in proportion to their allocation weight
  - If any single adapter cannot cover the withdrawal, pulls from others (waterfall logic)
  - Transfers USDC back to SavingsAccount
  - Emits `CapitalWithdrawn(amount, timestamp)`
- [ ] `allocationWeights` is a mapping from adapter address to `uint256` weight (in basis points, must sum to 10000)
- [ ] Governance can call `setAllocationWeights(address[] adapters, uint256[] weights)` with a 7-day timelock

### Harvesting
- [ ] `harvest()` — callable by anyone, executes the yield distribution cycle:
  - Calls `adapter.harvest()` on all active adapters
  - Sums total yield collected
  - Deducts protocol fee (`totalYield * feeRateBps / 10000`) → transfers to treasury
  - Deducts buffer contribution (`totalYield * bufferRateBps / 10000`) → credits to `CircleBuffer`
  - Distributes remaining yield proportionally across all savings positions
  - Emits `YieldHarvested(grossYield, protocolFee, bufferContribution, netYield)`
- [ ] `harvest()` is idempotent within a single block — calling twice returns 0 on second call
- [ ] `harvest()` is callable no more than once per hour (prevents MEV griefing)

### Circuit Breaker
- [ ] Before every `harvest()`, check `oracleAggregator.getRate()`:
  - If `circuitBreakerActive == true`: skip rebalancing, proceed with harvest at conservative rate
  - Log circuit breaker state in emitted event
- [ ] `rebalance()` — adjusts adapter allocations toward target weights:
  - Blocked if oracle circuit breaker is active
  - Callable by anyone once per 24 hours (prevents excessive gas consumption)

### Fee Collection
- [ ] `feeRateBps` — configurable by governance, default 1000 (10%), hard ceiling 2000 (20%), hard floor 0
- [ ] `bufferRateBps` — configurable by governance, default 500 (5%), hard ceiling 1000 (10%)
- [ ] Treasury address configurable by governance with 7-day timelock
- [ ] `getFeeInfo() returns (uint256 feeRate, uint256 bufferRate, address treasury)` — public view

### Blended APY
- [ ] `getBlendedAPY() returns (uint256 apyBps)`:
  - Calculates weighted average APY across all active adapters
  - Uses oracle data where available, falls back to adapter's own `getAPY()` otherwise

### Tests
- [ ] Unit tests at `test/unit/YieldRouter.test.ts` using mock adapters:
  - Allocate 1000 → mock adapters receive correct proportional amounts
  - Harvest → gross yield collected, fee deducted, buffer deducted, net distributed
  - `setAllocationWeights` with weights not summing to 10000 → reverts
  - `harvest()` twice in one block → second call returns 0
  - Circuit breaker active → `rebalance()` blocked, `harvest()` continues at fallback rate
  - Withdrawal covers amount across adapters correctly

---

## Output Files

- `contracts/yield/YieldRouter.sol`
- `test/unit/YieldRouter.test.ts`

---

## Notes

- Yield distribution across savings positions (the last step of `harvest()`) requires knowing all active positions and their balances. This creates a gas problem at scale. For v1: use an off-chain keeper that calls `harvest()` periodically and a Merkle-drop mechanism for yield distribution. The on-chain interface accepts proof of each position's entitled yield. Document this clearly in the contract.
- The Merkle-drop approach means members must claim their yield (or it is auto-credited by a keeper). This is a design compromise for v1; the target is fully on-chain automatic accrual when gas costs allow.
