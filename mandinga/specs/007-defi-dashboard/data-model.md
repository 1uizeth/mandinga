# Spec 007 — DeFi Dashboard: Data Model

**Date**: March 2026  
**Source**: [spec.md](./spec.md) Key Entities + contract interfaces

---

## Entities (from spec)

### User

| Attribute | Type | Source | Notes |
|-----------|------|--------|-------|
| address | `Address` | wagmi `useAccount` | Wallet address |
| isConnected | `boolean` | wagmi | Connection state |
| chainId | `number` | wagmi | Current chain |

**Relationships:** Has one SavingsAccount (via shieldedId); may participate in multiple SavingsCircles.

---

### Savings Account (Position)

| Attribute | Type | Source | Notes |
|-----------|------|--------|-------|
| shieldedId | `bytes32` | Derived from address + nonce | Position key |
| balanceUsdc | `bigint` | yieldRouter.convertToAssets(sharesBalance) | 6 decimals |
| sharesBalance | `bigint` | yieldRouter.balanceOf(account) | Raw shares |
| circleObligationShares | `bigint` | position.circleObligationShares | Locked shares |
| circleActive | `boolean` | position.circleActive | In a circle |
| withdrawableUsdc | `bigint` | convertToAssets(sharesBalance - circleObligationShares) | Available |

**Validation:** sharesBalance >= circleObligationShares (invariant).

**State transitions:** Deposit → balance/shares increase; Withdraw → decrease (if withdrawable); Join circle → circleActive true, obligation set.

---

### Savings Circle

| Attribute | Type | Source | Notes |
|-----------|------|--------|-------|
| circleId | `uint256` | circles(circleId) | Unique ID |
| poolSize | `uint256` | circle.poolSize | N × contributionPerMember |
| memberCount | `uint16` | circle.memberCount | N |
| contributionPerMember | `uint256` | circle.contributionPerMember | Per round |
| roundDuration | `uint256` | circle.roundDuration | Seconds |
| nextRoundTimestamp | `uint256` | circle.nextRoundTimestamp | Unix timestamp |
| status | `CircleStatus` | circle.status | FORMING, ACTIVE, COMPLETED |
| filledSlots | `uint16` | circle.filledSlots | Slots filled |
| roundsCompleted | `uint16` | circle.roundsCompleted | Rounds done |
| minDepositPerRound | `uint256` | circle.minDepositPerRound | 0 = disabled |

**Member-specific:**
| Attribute | Type | Source | Notes |
|-----------|------|--------|-------|
| slot | `uint16` | _members indexOf(shieldedId) | Member slot |
| payoutReceived | `boolean` | payoutReceived(circleId, slot) | Has received payout |
| positionPaused | `boolean` | positionPaused(circleId, slot) | Paused |

**Display derivations:**
- depositPerRound (USDC): contributionPerMember / 1e6
- poolSizeUsdc: poolSize / 1e6
- durationMonths: roundDuration × memberCount / (30 * 24 * 3600) approx.
- nextRoundDate: new Date(nextRoundTimestamp * 1000)

---

### Yield

| Attribute | Type | Source | Notes |
|-----------|------|--------|-------|
| cumulativeYieldUsdc | `bigint` | Derived | Total yield since first deposit |
| currentBalanceUsdc | `bigint` | From position | Current balance |
| principalUsdc | `bigint` | Historical or derived | Total deposited |
| yieldUsdc | `bigint` | currentBalance - principal | Approximate |

**Note:** Exact cumulative yield requires tracking deposit/withdrawal history or on-chain events. For v1, approximate as: `currentBalance - sum(deposits) + sum(withdrawals)` if tracked; else use share-price delta from initial deposit.

---

## Contract Read Patterns

| Data | Contract | Method / Pattern |
|------|----------|-----------------|
| shieldedId | SavingsAccount | getShieldedId(address) or keccak256(abi.encodePacked(address, nonce)) |
| position | SavingsAccount | getPosition(shieldedId) |
| sharesBalance | YieldRouter | balanceOf(SavingsAccount) |
| balanceUsdc | YieldRouter | convertToAssets(shares) |
| circle | SavingsCircle | circles(circleId) |
| user circles | SavingsCircle | Enumerate circles, filter by _members contains shieldedId |
| nextRoundTimestamp | SavingsCircle | circles(circleId).nextRoundTimestamp |

---

## UI State (client-side, not persisted)

| State | Purpose |
|-------|---------|
| theme | light / dark |
| selectedCircleId | For circle detail view |
| filterStatus | Status filter (All, Forming, Active, Completed) |
| sortBy | Sort order for circle list |
