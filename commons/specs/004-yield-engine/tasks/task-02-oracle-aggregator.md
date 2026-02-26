# Task 004-02 — Implement OracleAggregator

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Ready
**Estimated effort:** 4 hours
**Dependencies:** Task 004-01 (IYieldRouter interface)
**Parallel-safe:** Yes (no runtime dependency on 004-01, just conceptual context)

---

## Objective

Implement `OracleAggregator.sol` — a contract that aggregates rate data from multiple Chainlink Data Feed sources, detects anomalous deviations, and exposes a single manipulation-resistant rate for use by the YieldRouter.

---

## Context

The yield router needs current yield rates from external sources to make allocation decisions. A single oracle is a manipulation target. This aggregator takes a median of multiple sources, enforces freshness requirements, and trips a circuit breaker if any source deviates too far from the median.

See: Spec 004, US-003 (Oracle Integration).

---

## Acceptance Criteria

- [ ] Contract file created at `contracts/yield/OracleAggregator.sol`
- [ ] Constructor accepts an array of Chainlink AggregatorV3Interface addresses
- [ ] `getRate() returns (uint256 rate, bool circuitBreakerActive)`:
  - Queries all registered feeds
  - Filters out stale feeds (> 1 hour since `updatedAt`)
  - Returns the median of non-stale feeds
  - Sets `circuitBreakerActive = true` if any feed deviates > 20% from the median
  - Falls back to a configurable conservative floor rate if < 2 feeds are fresh
- [ ] `addFeed(address feed)` — owner-only, adds a new oracle source
- [ ] `removeFeed(address feed)` — owner-only, removes a source
- [ ] `setFallbackRate(uint256 rateBps)` — owner-only, sets the conservative floor APY
- [ ] `setMaxDeviation(uint256 bps)` — owner-only, configures the deviation threshold (default: 2000 = 20%)
- [ ] `setMaxStaleness(uint256 seconds)` — owner-only, configures the freshness window (default: 3600)
- [ ] Unit tests in `test/unit/OracleAggregator.test.ts`:
  - Happy path: 3 fresh feeds → correct median returned
  - Stale feed: 1 of 3 feeds stale → median of remaining 2 used
  - Deviation trip: 1 feed deviates 25% → circuit breaker active
  - All feeds stale → fallback rate returned, circuit breaker active
  - Only 1 fresh feed → fallback rate returned (below 2-feed minimum)
- [ ] All tests passing

---

## Output Files

- `contracts/yield/OracleAggregator.sol`
- `test/unit/OracleAggregator.test.ts`

---

## Notes

- Chainlink feeds return rates in their own format (check `decimals()` on each feed and normalise to basis points)
- The median of an even-length array should use the average of the two middle values
- Owner in this context is the `CommonsGovernor` timelock — not an EOA
- Do not use SafeMath explicitly (Solidity 0.8+ has overflow protection built in)
