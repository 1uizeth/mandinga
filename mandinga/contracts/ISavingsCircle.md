# Interface Contract: ISavingsCircle

**File:** `backend/contracts/interfaces/ISavingsCircle.sol`
**Spec:** 002 — Savings Circle
**Solidity:** ^0.8.20

---

## Functions

### Member-facing

| Signature | Access | Description |
|---|---|---|
| `joinCircle(uint256 circleId)` | public | Join a FORMING circle (requires balance proof check via SavingsAccount) |
| `executeRound(uint256 circleId)` | public (permissionless) | Trigger next round after `nextRoundTimestamp`; requests Chainlink VRF |

### View

| Signature | Returns | Description |
|---|---|---|
| `getCircle(uint256 circleId)` | `Circle` | Full circle struct |
| `getMemberSlot(uint256 circleId, bytes32 shieldedId)` | `uint8` | Slot number for a member |
| `isEligibleForSelection(uint256 circleId, uint8 slot)` | `bool` | Not paused AND payout not yet received |
| `getNextRoundTimestamp(uint256 circleId)` | `uint256` | Timestamp when next round can execute |

### VRF Callback (internal)

| Signature | Caller | Description |
|---|---|---|
| `fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)` | VRFCoordinator only | Select winner from eligible members; update obligations; emit MemberSelected |

---

## Events

| Event | Parameters |
|---|---|
| `CircleCreated` | `uint256 indexed circleId, uint256 poolSize, uint8 memberCount` |
| `MemberJoined` | `uint256 indexed circleId, uint8 slot` (no shieldedId in event) |
| `RoundExecuted` | `uint256 indexed circleId, uint8 roundNumber, uint256 timestamp` |
| `MemberSelected` | `uint256 indexed circleId, uint8 roundNumber` (winner identity NOT in event) |
| `MemberPaused` | `uint256 indexed circleId, uint8 slot` |
| `MemberResumed` | `uint256 indexed circleId, uint8 slot` |
| `CircleCompleted` | `uint256 indexed circleId` |

---

## Custom Errors

| Error | Parameters |
|---|---|
| `RoundNotReady` | `uint256 nextRoundTimestamp, uint256 current` |
| `CircleNotActive` | `CircleStatus status` |
| `AlreadyJoined` | `bytes32 shieldedId` |
| `CircleFull` | `uint256 circleId` |
| `InsufficientBalance` | `bytes32 shieldedId, uint256 required` |

---

## Notes

- `executeRound()` is permissionless — any address can call it; output is determined entirely by VRF, not the caller
- Member identity is never emitted in events — only slot number and circle ID
- A paused member does not cause circle failure; they are skipped in selection until resumed
