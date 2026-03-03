# Interface Contract: ISolidarityMarket

**File:** `backend/contracts/interfaces/ISolidarityMarket.sol`
**Spec:** 003 — Solidarity Market
**Solidity:** ^0.8.20

---

## Functions

### Member-facing

| Signature | Access | Description |
|---|---|---|
| `createVouch(bytes32 vouchedId, uint256 amount, uint256 circleId, uint256 interestRateBps, uint256 payoutShareBps)` | public | Lock `amount` of voucher's balance as a vouch |
| `claimInterest(bytes32 vouchId)` | public | Claim accrued interest earned on active vouch |
| `cancelVouch(bytes32 vouchId)` | public | Cancel vouch if circle not yet ACTIVE |

### View

| Signature | Returns | Description |
|---|---|---|
| `getVouch(bytes32 vouchId)` | `Vouch` | Full vouch struct |
| `getActiveVouches(bytes32 shieldedId)` | `bytes32[]` | Vouch IDs where `shieldedId` is voucher |
| `getAccruedInterest(bytes32 vouchId)` | `uint256` | Claimable interest in USDC |
| `getMaxVouchAmount(bytes32 voucherId)` | `uint256` | Max allowed vouch = 20% of voucher's balance (80% floor) |

### Circle callback (internal)

| Signature | Caller | Description |
|---|---|---|
| `onMemberSelected(uint256 circleId, bytes32 selectedShieldedId)` | SavingsCircle only | Distribute payout share to voucher; update vouch status to COMPLETED |

---

## Events

| Event | Parameters |
|---|---|
| `VouchCreated` | `bytes32 indexed vouchId, uint256 indexed circleId, uint256 amount` |
| `InterestClaimed` | `bytes32 indexed vouchId, uint256 amount` |
| `PayoutShareDistributed` | `bytes32 indexed vouchId, uint256 amount` |
| `VouchPaused` | `bytes32 indexed vouchId` |
| `VouchResumed` | `bytes32 indexed vouchId` |
| `VouchCompleted` | `bytes32 indexed vouchId` |
| `VouchExpired` | `bytes32 indexed vouchId` |

---

## Custom Errors

| Error | Parameters |
|---|---|
| `VouchExceedsDiversificationFloor` | `uint256 amount, uint256 maxAllowed` |
| `VouchedMemberNotInCircle` | `bytes32 vouchedId, uint256 circleId` |
| `VouchAlreadyActive` | `bytes32 vouchId` |
| `NotAuthorized` | `address caller` |

---

## Notes

- Interest accrues per block from vouch creation; claimable at any time
- Payout share distributed automatically via `onMemberSelected` callback from SavingsCircle
- 80% diversification floor: no single vouch may exceed 20% of voucher's `SavingsAccount` balance
- Vouch pauses (not defaults) when vouched member's circle position is paused
