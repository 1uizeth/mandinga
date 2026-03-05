// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICircleBuffer} from "../interfaces/ICircleBuffer.sol";
import {IYieldRouter} from "../interfaces/IYieldRouter.sol";
import {ISavingsAccount} from "../interfaces/ISavingsAccount.sol";

/// @title SafetyNetPool
/// @notice The Safety Net Pool enables minimum-installment coverage for SavingsCircle members.
///
/// @dev v1 scope (Spec 003 v1.0):
///  • Depositors lock USDC into the pool; capital is immediately routed to the YieldRouter
///    so it earns yield from block 1.
///  • The pool implements ICircleBuffer — SavingsCircle calls `coverSlot` / `releaseSlot`
///    when a member is paused / resumes.
///  • Coverage is pool-level fungible: no per-depositor attribution of covered slots.
///  • Withdrawals are pro-rata on available (undeployed) capital.
///
/// Deferred to v2 / pending open questions:
///  • safetyNetDebtShares + minimum-installment mechanics (OQ-004, OQ-005)
///  • Reallocation coverage window enforcement (OQ-002)
///  • Lock-duration deployment preference (OQ-003)
///  • ZK proof for debt settlement (OQ-004)
contract SafetyNetPool is ICircleBuffer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    // Constants
    // ──────────────────────────────────────────────

    /// @notice Default coverage window before circle shrinks to N-1. (OQ-002)
    uint8 public constant COVERAGE_WINDOW_ROUNDS = 3;

    // ──────────────────────────────────────────────
    // Immutables
    // ──────────────────────────────────────────────

    ISavingsAccount public immutable savingsAccount;
    IYieldRouter public immutable yieldRouter;
    IERC20 public immutable usdc;

    /// @notice The single SavingsCircle contract authorised to call coverSlot/releaseSlot.
    address public immutable circle;

    /// @notice Address allowed to update governance parameters.
    address public immutable governance;

    // ──────────────────────────────────────────────
    // Governance state
    // ──────────────────────────────────────────────

    /// @notice Annual coverage interest rate charged to covered members (OQ-005 placeholder).
    uint256 public coverageRateBps;

    // ──────────────────────────────────────────────
    // Pool-level accounting
    // ──────────────────────────────────────────────

    /// @notice Fractional-ownership shares for each pool depositor.
    /// @dev Pool share value = poolValue() / totalPoolShares
    mapping(bytes32 shieldedId => uint256 shares) public poolShares;

    /// @notice Total pool shares outstanding.
    uint256 public totalPoolShares;

    /// @notice Total YieldRouter shares held by this contract.
    uint256 public totalYRShares;

    /// @notice USDC equivalent currently committed to active slot coverages.
    uint256 public totalDeployed;

    // ──────────────────────────────────────────────
    // Per-depositor metadata (informational)
    // ──────────────────────────────────────────────

    struct PoolPosition {
        uint256 lockExpiry;   // block.timestamp when declared lock ends
    }

    mapping(bytes32 shieldedId => PoolPosition) public positions;

    // ──────────────────────────────────────────────
    // Slot coverage tracking
    // ──────────────────────────────────────────────

    struct SlotCoverage {
        uint256 amount;           // USDC per round committed to cover this slot
        uint256 startTimestamp;
    }

    mapping(uint256 circleId => mapping(uint16 slot => SlotCoverage)) public slotCoverages;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event Deposited(bytes32 indexed shieldedId, uint256 amount, uint256 lockDuration, uint256 newPoolShares);
    event Withdrawn(bytes32 indexed shieldedId, uint256 amount, uint256 burntPoolShares);
    event SlotCovered(uint256 indexed circleId, uint16 indexed slot, uint256 amount);
    event SlotReleased(uint256 indexed circleId, uint16 indexed slot, uint256 amount);
    event CoverageRateUpdated(uint256 oldBps, uint256 newBps);

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    error ZeroAmount();
    error InsufficientAvailableCapital(uint256 available, uint256 required);
    error InsufficientWithdrawable(uint256 withdrawable, uint256 requested);
    error SlotNotCovered(uint256 circleId, uint16 slot);
    error OnlyCircle();
    error OnlyGovernance();
    error NoPosition();

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(
        ISavingsAccount _savingsAccount,
        IYieldRouter _yieldRouter,
        IERC20 _usdc,
        address _circle,
        address _governance,
        uint256 _initialRateBps
    ) {
        savingsAccount = _savingsAccount;
        yieldRouter = _yieldRouter;
        usdc = _usdc;
        circle = _circle;
        governance = _governance;
        coverageRateBps = _initialRateBps;
    }

    // ──────────────────────────────────────────────
    // Deposit
    // ──────────────────────────────────────────────

    /// @notice Deposit USDC into the Safety Net Pool.
    /// @param amount       USDC amount (6 decimals, >= 1 USDC)
    /// @param lockDuration Seconds for declared lock period (informational in v1)
    function deposit(uint256 amount, uint256 lockDuration) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        bytes32 shieldedId = savingsAccount.computeShieldedId(msg.sender);

        // Capture pool value BEFORE this deposit to price new shares correctly
        uint256 prevPoolValue = _poolValue();

        // Pull USDC, route to YieldRouter
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.forceApprove(address(yieldRouter), amount);
        uint256 yrSharesMinted = yieldRouter.deposit(amount, address(this));
        totalYRShares += yrSharesMinted;

        // Mint pool shares proportional to contribution
        uint256 newShares;
        if (totalPoolShares == 0 || prevPoolValue == 0) {
            newShares = amount;   // 1 share per USDC for first depositor
        } else {
            newShares = (amount * totalPoolShares) / prevPoolValue;
        }

        poolShares[shieldedId] += newShares;
        totalPoolShares += newShares;
        positions[shieldedId].lockExpiry = block.timestamp + lockDuration;

        emit Deposited(shieldedId, amount, lockDuration, newShares);
    }

    // ──────────────────────────────────────────────
    // Withdraw
    // ──────────────────────────────────────────────

    /// @notice Withdraw capital from the pool.
    /// @dev Only undeployed (available) capital can be withdrawn. Per AC-002-1,
    ///      undeployed capital is withdrawable regardless of declared lock duration.
    /// @param amount USDC amount to withdraw
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        bytes32 shieldedId = savingsAccount.computeShieldedId(msg.sender);
        if (poolShares[shieldedId] == 0) revert NoPosition();

        uint256 withdrawable = getWithdrawable(shieldedId);
        if (amount > withdrawable) revert InsufficientWithdrawable(withdrawable, amount);

        // Burn pool shares proportional to withdrawal amount
        uint256 pv = _poolValue();
        uint256 sharesToBurn = (amount * totalPoolShares) / pv;
        // Cap at depositor's shares to avoid rounding overflow
        if (sharesToBurn > poolShares[shieldedId]) sharesToBurn = poolShares[shieldedId];

        poolShares[shieldedId] -= sharesToBurn;
        totalPoolShares -= sharesToBurn;

        // Redeem from YieldRouter — sends USDC directly to caller
        uint256 yrSharesRedeemed = yieldRouter.withdraw(amount, msg.sender, address(this));
        totalYRShares -= yrSharesRedeemed;

        emit Withdrawn(shieldedId, amount, sharesToBurn);
    }

    // ──────────────────────────────────────────────
    // ICircleBuffer
    // ──────────────────────────────────────────────

    /// @inheritdoc ICircleBuffer
    /// @dev Callable only by the authorised SavingsCircle contract.
    ///      Checks that pool has sufficient available (undeployed) capital.
    function coverSlot(uint256 circleId, uint16 slot, uint256 amount) external override nonReentrant {
        if (msg.sender != circle) revert OnlyCircle();

        uint256 available = getAvailableCapital();
        if (available < amount) revert InsufficientAvailableCapital(available, amount);

        slotCoverages[circleId][slot] = SlotCoverage({amount: amount, startTimestamp: block.timestamp});
        totalDeployed += amount;

        emit SlotCovered(circleId, slot, amount);
    }

    /// @inheritdoc ICircleBuffer
    function releaseSlot(uint256 circleId, uint16 slot) external override nonReentrant {
        if (msg.sender != circle) revert OnlyCircle();

        SlotCoverage storage cov = slotCoverages[circleId][slot];
        if (cov.amount == 0) revert SlotNotCovered(circleId, slot);

        uint256 amount = cov.amount;
        delete slotCoverages[circleId][slot];
        totalDeployed -= amount;

        emit SlotReleased(circleId, slot, amount);
    }

    // ──────────────────────────────────────────────
    // Governance
    // ──────────────────────────────────────────────

    /// @notice Update the annual coverage interest rate.
    /// @param newRateBps New rate in basis points (e.g., 500 = 5% APY)
    function setCoverageRate(uint256 newRateBps) external {
        if (msg.sender != governance) revert OnlyGovernance();
        emit CoverageRateUpdated(coverageRateBps, newRateBps);
        coverageRateBps = newRateBps;
    }

    // ──────────────────────────────────────────────
    // View helpers
    // ──────────────────────────────────────────────

    /// @notice Total USDC value held by the pool (principal + accrued yield).
    function getTotalCapital() external view returns (uint256) {
        return _poolValue();
    }

    /// @notice Undeployed USDC available for new slot coverages.
    function getAvailableCapital() public view returns (uint256) {
        uint256 total = _poolValue();
        return total > totalDeployed ? total - totalDeployed : 0;
    }

    /// @notice Pro-rata withdrawable USDC for a depositor.
    /// @dev Returns 0 if no position exists.
    function getWithdrawable(bytes32 shieldedId) public view returns (uint256) {
        uint256 shares = poolShares[shieldedId];
        if (shares == 0 || totalPoolShares == 0) return 0;

        uint256 available = getAvailableCapital();
        // Depositor's pro-rata share of available capital
        return (available * shares) / totalPoolShares;
    }

    /// @notice Current USDC value of a depositor's entire position (including yield).
    function getPositionValue(bytes32 shieldedId) external view returns (uint256) {
        uint256 shares = poolShares[shieldedId];
        if (shares == 0 || totalPoolShares == 0) return 0;
        return (_poolValue() * shares) / totalPoolShares;
    }

    // ──────────────────────────────────────────────
    // Internal helpers
    // ──────────────────────────────────────────────

    function _poolValue() internal view returns (uint256) {
        if (totalYRShares == 0) return 0;
        return yieldRouter.convertToAssets(totalYRShares);
    }
}
