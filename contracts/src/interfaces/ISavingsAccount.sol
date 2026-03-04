// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISavingsAccount
/// @notice Public API surface for the core savings primitive.
/// @dev All other contracts (SavingsCircle, SolidarityMarket) interact with savings accounts
///      exclusively through this interface.
interface ISavingsAccount {
    // ──────────────────────────────────────────────
    // Structs
    // ──────────────────────────────────────────────

    /// @notice Full state of a member's savings position.
    struct Position {
        uint256 balance;
        uint256 circleObligation;
        uint256 yieldEarnedTotal;
        uint256 lastUpdateTimestamp;
        bool emergencyExit;
    }

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when USDC is deposited.
    event Deposited(bytes32 indexed shieldedId, uint256 amount);

    /// @notice Emitted when USDC is withdrawn.
    event Withdrawn(bytes32 indexed shieldedId, uint256 amount);

    /// @notice Emitted when the yield router credits yield to a position.
    event YieldCredited(bytes32 indexed shieldedId, uint256 amount);

    /// @notice Emitted when the circle obligation for a position is updated.
    event ObligationSet(bytes32 indexed shieldedId, uint256 newObligation);

    /// @notice Emitted when a member exits via the emergency path.
    event EmergencyExitExecuted(bytes32 indexed shieldedId, uint256 amountReturned);

    // ──────────────────────────────────────────────
    // Custom Errors
    // ──────────────────────────────────────────────

    /// @notice Raised when a withdrawal exceeds the withdrawable (unlocked) balance.
    error InsufficientWithdrawableBalance(uint256 requested, uint256 available);

    /// @notice Raised when an obligation set would violate balance >= obligation.
    error PrincipalLockViolation(uint256 balance, uint256 obligation);

    /// @notice Raised when an unauthorised address calls a restricted function.
    error NotAuthorized(address caller, address expected);

    /// @notice Raised when emergencyWithdraw is called but emergency is not active.
    error EmergencyNotActive();

    // ──────────────────────────────────────────────
    // Functions
    // ──────────────────────────────────────────────

    /// @notice Deposit USDC; funds start yielding immediately via the yield router.
    /// @param amount USDC amount (6 decimals)
    function deposit(uint256 amount) external;

    /// @notice Withdraw up to `balance - circleObligation` USDC.
    /// @param amount USDC amount to withdraw (6 decimals)
    function withdraw(uint256 amount) external;

    /// @notice Full withdrawal in emergency state — circle obligation is released.
    /// @dev Only callable when the emergency module has activated the emergency flag.
    function emergencyWithdraw() external;

    /// @notice Returns the full position for a given shielded identity.
    /// @param shieldedId Opaque commitment derived from member address + nonce.
    /// @return position The Position struct; all fields zero for unknown shieldedIds.
    function getPosition(bytes32 shieldedId) external view returns (Position memory position);

    /// @notice Returns `balance - circleObligation` for a position (safe to withdraw).
    /// @param shieldedId Opaque commitment derived from member address + nonce.
    function getWithdrawableBalance(bytes32 shieldedId) external view returns (uint256);

    /// @notice Returns the currently locked circle obligation for a position.
    /// @param shieldedId Opaque commitment derived from member address + nonce.
    function getCircleObligation(bytes32 shieldedId) external view returns (uint256);

    /// @notice Set or update the circle obligation for a position.
    /// @dev Callable only by the SavingsCircle contract. Reverts if obligation > balance.
    /// @param shieldedId Opaque commitment derived from member address + nonce.
    /// @param amount New obligation amount (USDC, 6 decimals)
    function setCircleObligation(bytes32 shieldedId, uint256 amount) external;

    /// @notice Activate the global emergency flag, unlocking all positions.
    /// @dev Callable only by the EmergencyModule (timelock-gated).
    function activateEmergency() external;

    /// @notice Credit a principal increase to a position (ROSCA payout mechanism).
    /// @dev Callable only by the SavingsCircle contract. Semantically distinct from
    ///      `creditYield` — this is a principal transfer, not yield accrual.
    /// @param shieldedId Target position
    /// @param amount USDC amount to credit (6 decimals)
    function creditPrincipal(bytes32 shieldedId, uint256 amount) external;

    /// @notice Compute the shieldedId for a given user address.
    /// @dev v1: keccak256(abi.encodePacked(user, nonce)) where nonce = 0.
    /// @param user The member's wallet address
    /// @return shieldedId Derived opaque identity commitment
    function computeShieldedId(address user) external view returns (bytes32 shieldedId);
}
