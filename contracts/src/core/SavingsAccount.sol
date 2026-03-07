// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ISavingsAccount} from "../interfaces/ISavingsAccount.sol";
import {IYieldRouter} from "../interfaces/IYieldRouter.sol";

/// @title SavingsAccount
/// @notice Core savings primitive. Holds member positions, enforces the principal lock
///         invariant (`balance >= circleObligation`), routes yield through the YieldRouter,
///         and exposes the emergency exit path.
/// @dev Positions are keyed by `shieldedId = keccak256(abi.encodePacked(user, nonce))`.
contract SavingsAccount is ISavingsAccount, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    // Immutables
    // ──────────────────────────────────────────────

    /// @notice Yield router that holds capital and accrues yield.
    IYieldRouter public immutable yieldRouter;

    /// @notice Only address permitted to call `activateEmergency()`.
    address public immutable emergencyModule;

    /// @notice Only address permitted to call `setCircleObligation()` and `clearSafetyNetDebt()`.
    address public immutable savingsCircle;

    /// @notice Only address permitted to call `addSafetyNetDebt()` and `chargeFromYield()`.
    address public immutable safetyNetPool;

    /// @notice USDC stablecoin accepted as the deposit asset.
    IERC20 public immutable stablecoin;

    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    /// @notice Position data keyed by shieldedId.
    mapping(bytes32 => Position) private _positions;

    /// @notice Sum of all position balances (principal). Used for yield display.
    uint256 public totalPrincipal;

    /// @dev Per-user nonce used to derive the shieldedId.
    ///      v1 keeps nonce at 0 for each user (one position per address).
    mapping(address => uint256) private _commitmentNonces;

    /// @notice Global emergency flag — when true, all positions can withdraw in full.
    bool public emergencyActive;

    // ──────────────────────────────────────────────
    // Additional events (not in ISavingsAccount)
    // ──────────────────────────────────────────────

    /// @notice Emitted when the global emergency is activated.
    event EmergencyActivated();

    // ──────────────────────────────────────────────
    // Additional errors (not in ISavingsAccount)
    // ──────────────────────────────────────────────

    error ZeroAmount();
    error EmergencyAlreadyActive();
    error PositionAlreadyExited();

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlyEmergencyModule() {
        if (msg.sender != emergencyModule) revert NotAuthorized(msg.sender, emergencyModule);
        _;
    }

    modifier onlySavingsCircle() {
        if (msg.sender != savingsCircle) revert NotAuthorized(msg.sender, savingsCircle);
        _;
    }

    modifier onlySafetyNetPool() {
        if (msg.sender != safetyNetPool) revert NotAuthorized(msg.sender, safetyNetPool);
        _;
    }

    modifier onlyYieldRouter() {
        if (msg.sender != address(yieldRouter)) revert NotAuthorized(msg.sender, address(yieldRouter));
        _;
    }

    modifier whenEmergency() {
        if (!emergencyActive) revert EmergencyNotActive();
        _;
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(
        IYieldRouter _yieldRouter,
        address _emergencyModule,
        address _savingsCircle,
        address _stablecoin,
        address _safetyNetPool
    ) {
        yieldRouter = _yieldRouter;
        emergencyModule = _emergencyModule;
        savingsCircle = _savingsCircle;
        stablecoin = IERC20(_stablecoin);
        safetyNetPool = _safetyNetPool;
    }

    // ──────────────────────────────────────────────
    // Core functions
    // ──────────────────────────────────────────────

    /// @inheritdoc ISavingsAccount
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        bytes32 shieldedId = _computeShieldedId(msg.sender);

        // Pull USDC from caller, approve router, update balance, then allocate.
        // State is updated before the external call (checks-effects-interactions).
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        _positions[shieldedId].balance += amount;
        _positions[shieldedId].lastUpdateTimestamp = block.timestamp;
        totalPrincipal += amount;

        stablecoin.forceApprove(address(yieldRouter), amount);
        yieldRouter.allocate(amount);

        _assertInvariant(shieldedId);

        emit Deposited(shieldedId, amount);
    }

    /// @inheritdoc ISavingsAccount
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        bytes32 shieldedId = _computeShieldedId(msg.sender);
        Position storage pos = _positions[shieldedId];

        uint256 withdrawable = pos.balance - pos.circleObligation;
        if (withdrawable < amount) revert InsufficientWithdrawableBalance(amount, withdrawable);

        // Update state before external calls (checks-effects-interactions).
        pos.balance -= amount;
        pos.lastUpdateTimestamp = block.timestamp;
        totalPrincipal -= amount;

        // ERC4626 withdraw: burns shares from this contract, sends USDC to msg.sender.
        yieldRouter.withdraw(amount, msg.sender, address(this));

        _assertInvariant(shieldedId);

        emit Withdrawn(shieldedId, amount);
    }

    /// @inheritdoc ISavingsAccount
    function emergencyWithdraw() external nonReentrant whenEmergency {
        bytes32 shieldedId = _computeShieldedId(msg.sender);
        Position storage pos = _positions[shieldedId];

        if (pos.emergencyExit) revert PositionAlreadyExited();

        uint256 fullBalance = pos.balance;
        if (fullBalance == 0) revert InsufficientWithdrawableBalance(0, 0);

        // Release obligation and mark position as exited before external call.
        pos.circleObligation = 0;
        pos.balance = 0;
        totalPrincipal -= fullBalance;
        pos.emergencyExit = true;
        pos.lastUpdateTimestamp = block.timestamp;

        // ERC4626 withdraw: burns shares from this contract, sends USDC to msg.sender.
        yieldRouter.withdraw(fullBalance, msg.sender, address(this));

        emit EmergencyExitExecuted(shieldedId, fullBalance);
    }

    /// @inheritdoc ISavingsAccount
    /// @dev Callable only by the SavingsCircle contract. Used to credit ROSCA payouts
    ///      (principal increase) to the selected member's balance.
    function creditPrincipal(bytes32 shieldedId, uint256 amount) external onlySavingsCircle {
        if (amount == 0) return;

        _positions[shieldedId].balance += amount;
        _positions[shieldedId].lastUpdateTimestamp = block.timestamp;
        totalPrincipal += amount;

        _assertInvariant(shieldedId);

        emit YieldCredited(shieldedId, amount);
    }

    /// @notice Credit yield earned from the router to a specific position.
    /// @dev Callable only by the YieldRouter. In the share-price-appreciation model the
    ///      router pushes yield to each credited position after harvesting.
    /// @param shieldedId Target position
    /// @param amount USDC yield amount (6 decimals)
    function creditYield(bytes32 shieldedId, uint256 amount) external onlyYieldRouter {
        if (amount == 0) return;

        _positions[shieldedId].balance += amount;
        _positions[shieldedId].yieldEarnedTotal += amount;
        _positions[shieldedId].lastUpdateTimestamp = block.timestamp;
        totalPrincipal += amount;

        _assertInvariant(shieldedId);

        emit YieldCredited(shieldedId, amount);
    }

    /// @inheritdoc ISavingsAccount
    function setCircleObligation(bytes32 shieldedId, uint256 amount) external onlySavingsCircle {
        Position storage pos = _positions[shieldedId];

        if (pos.balance < amount) revert PrincipalLockViolation(pos.balance, amount);

        pos.circleObligation = amount;
        pos.lastUpdateTimestamp = block.timestamp;

        _assertInvariant(shieldedId);

        emit ObligationSet(shieldedId, amount);
    }

    /// @inheritdoc ISavingsAccount
    function activateEmergency() external onlyEmergencyModule {
        if (emergencyActive) revert EmergencyAlreadyActive();
        emergencyActive = true;
        emit EmergencyActivated();
    }

    // ──────────────────────────────────────────────
    // Safety Net Pool integration (Task 003-02, 003-03, 003-04)
    // ──────────────────────────────────────────────

    /// @inheritdoc ISavingsAccount
    function addSafetyNetDebt(bytes32 shieldedId, uint256 shares) external onlySafetyNetPool {
        if (shares == 0) return;
        _positions[shieldedId].safetyNetDebtShares += shares;
        emit SafetyNetDebtAdded(shieldedId, shares);
    }

    /// @inheritdoc ISavingsAccount
    function getSafetyNetDebtShares(bytes32 shieldedId) external view returns (uint256) {
        return _positions[shieldedId].safetyNetDebtShares;
    }

    /// @inheritdoc ISavingsAccount
    function clearSafetyNetDebt(bytes32 shieldedId) external onlySavingsCircle {
        uint256 settled = _positions[shieldedId].safetyNetDebtShares;
        if (settled == 0) return;
        _positions[shieldedId].safetyNetDebtShares = 0;
        emit SafetyNetDebtCleared(shieldedId, settled);
    }

    /// @inheritdoc ISavingsAccount
    /// @dev Charges from yieldEarnedTotal first; remainder from free balance.
    ///      Free balance = balance - circleObligation (locked principal excluded).
    function chargeFromYield(bytes32 shieldedId, uint256 amount) external onlySafetyNetPool {
        if (amount == 0) return;
        Position storage pos = _positions[shieldedId];

        uint256 fromYield;
        uint256 fromBalance;

        if (pos.yieldEarnedTotal >= amount) {
            fromYield = amount;
            pos.yieldEarnedTotal -= amount;
            pos.balance -= amount;
        } else {
            fromYield = pos.yieldEarnedTotal;
            uint256 remainder = amount - fromYield;

            uint256 freeBalance = pos.balance > pos.circleObligation
                ? pos.balance - pos.circleObligation
                : 0;
            if (freeBalance < remainder) revert PositionInsolvent(shieldedId);

            fromBalance = remainder;
            pos.yieldEarnedTotal = 0;
            pos.balance -= amount;
        }

        pos.lastUpdateTimestamp = block.timestamp;
        totalPrincipal -= amount;
        emit YieldCharged(shieldedId, amount, fromYield, fromBalance);
    }

    // ──────────────────────────────────────────────
    // View functions
    // ──────────────────────────────────────────────

    /// @inheritdoc ISavingsAccount
    function getPosition(bytes32 shieldedId) external view returns (Position memory) {
        return _positions[shieldedId];
    }

    /// @inheritdoc ISavingsAccount
    function getWithdrawableBalance(bytes32 shieldedId) external view returns (uint256) {
        Position storage pos = _positions[shieldedId];
        return pos.balance - pos.circleObligation;
    }

    /// @inheritdoc ISavingsAccount
    function getCircleObligation(bytes32 shieldedId) external view returns (uint256) {
        return _positions[shieldedId].circleObligation;
    }

    /// @notice Compute the shieldedId for a given user address.
    /// @dev Off-chain callers can use this to look up positions without knowing raw addresses.
    /// @param user The member's wallet address
    /// @return shieldedId keccak256(abi.encodePacked(user, nonce))
    function computeShieldedId(address user) external view returns (bytes32) {
        return _computeShieldedId(user);
    }

    // ──────────────────────────────────────────────
    // Internal helpers
    // ──────────────────────────────────────────────

    function _computeShieldedId(address user) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(user, _commitmentNonces[user]));
    }

    /// @dev Invariant guard — asserts balance >= obligation after every state mutation.
    ///      Required for testnet; can be removed after formal verification in production.
    function _assertInvariant(bytes32 shieldedId) internal view {
        Position storage pos = _positions[shieldedId];
        assert(pos.balance >= pos.circleObligation);
    }
}
