# Interface Contract: ISavingsAccount

**File:** `backend/contracts/interfaces/ISavingsAccount.sol`
**Spec:** 001 — Savings Account
**Solidity:** ^0.8.20

---

## Identity

All functions use `bytes32 shieldedId` (never raw `address`) to identify positions.
In v1: `shieldedId = keccak256(abi.encodePacked(msg.sender, nonce))`.

---

## Structs

```solidity
struct Position {
    uint256 circleObligationShares;  // min shares that cannot be redeemed
    uint256 solidarityDebtShares;    // shares owed to Solidarity Pool
    uint256 lastYieldUpdate;         // block timestamp for display
    bool    circleActive;
}
```

---

## Functions

### Member-facing

| Signature | Access | Description |
|---|---|---|
| `deposit(uint256 amount)` | public | Deposit USDC; routes to YieldRouter; credits shares |
| `withdraw(uint256 amount)` | public | Withdraw up to `sharesBalance - circleObligationShares` |
| `emergencyWithdraw()` | public | Full withdrawal in emergency state (obligation released) |

### View

| Signature | Returns | Description |
|---|---|---|
| `getPosition(bytes32 shieldedId)` | `Position` | Full position struct |
| `getWithdrawableBalance(bytes32 shieldedId)` | `uint256` | USDC-equivalent withdrawable amount |
| `getCircleObligation(bytes32 shieldedId)` | `uint256` | USDC-equivalent of locked obligation |
| `getSharesBalance(bytes32 shieldedId)` | `uint256` | Raw shares balance from YieldRouter |

### Protocol-internal (access-controlled)

| Signature | Caller | Description |
|---|---|---|
| `setCircleObligation(bytes32 shieldedId, uint256 shares)` | SavingsCircle only | Set `circleObligationShares`; reverts if `sharesBalance < shares` |
| `setSolidarityDebt(bytes32 shieldedId, uint256 shares)` | SolidarityMarket only | Set `solidarityDebtShares` |
| `activateEmergency()` | EmergencyModule only | Set global `emergencyActive = true` |

---

## Events

| Event | Parameters |
|---|---|
| `Deposited` | `bytes32 indexed shieldedId, uint256 amount` |
| `Withdrawn` | `bytes32 indexed shieldedId, uint256 amount` |
| `ObligationSet` | `bytes32 indexed shieldedId, uint256 newObligationShares` |
| `SolidarityDebtSet` | `bytes32 indexed shieldedId, uint256 debtShares` |
| `EmergencyActivated` | — |
| `EmergencyExitExecuted` | `bytes32 indexed shieldedId, uint256 amountReturned` |

---

## Custom Errors

| Error | Parameters |
|---|---|
| `InsufficientWithdrawableBalance` | `uint256 requested, uint256 available` |
| `PrincipalLockViolation` | `uint256 sharesBalance, uint256 circleObligationShares` |
| `NotAuthorized` | `address caller, address expected` |
| `EmergencyNotActive` | — |
| `ZeroAmount` | — |

---

## Invariant

`yieldRouter.balanceOf(address(this)) >= circleObligationShares[shieldedId]` at all times.
Checked on every state-modifying function.
