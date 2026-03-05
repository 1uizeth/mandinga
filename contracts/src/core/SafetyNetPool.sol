// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICircleBuffer} from "../interfaces/ICircleBuffer.sol";
import {ISafetyNetPool} from "../interfaces/ISafetyNetPool.sol";
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
contract SafetyNetPool is ISafetyNetPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    // Constants
    // ──────────────────────────────────────────────

    /// @notice Default coverage window before circle shrinks to N-1. (OQ-002)
    uint8 public constant COVERAGE_WINDOW_ROUNDS = 3;

    /// @notice Minimum allowed minDepositPerRound (1 USDC in 6-decimal).
    uint256 public constant MIN_MIN_DEPOSIT = 1e6;

    /// @notice Minimum elapsed time between accrueInterest calls for the same slot.
    uint256 public constant MIN_ACCRUAL_INTERVAL = 1 hours;

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

    /// @notice USDC equivalent currently committed to active slot and gap coverages.
    uint256 public totalDeployed;

    /// @notice Total USDC interest collected from covered members (accounting; not minted to pool yet).
    uint256 public totalInterestCollected;

    // ──────────────────────────────────────────────
    // Per-depositor metadata (informational)
    // ──────────────────────────────────────────────

    struct PoolPosition {
        uint256 lockExpiry;   // block.timestamp when declared lock ends
    }

    mapping(bytes32 shieldedId => PoolPosition) public positions;

    // ──────────────────────────────────────────────
    // Slot coverage tracking (pause/resume)
    // ──────────────────────────────────────────────

    struct SlotCoverage {
        uint256 amount;           // USDC per round committed to cover this slot
        uint256 startTimestamp;
    }

    mapping(uint256 circleId => mapping(uint16 slot => SlotCoverage)) public slotCoverages;

    // ──────────────────────────────────────────────
    // Gap coverage tracking (min-installment, Task 003-02)
    // ──────────────────────────────────────────────

    /// @notice Canonical GapCoverage struct (authoritative definition; tasks 03 and 04 reference this).
    struct GapCoverage {
        bytes32 memberId;            // shieldedId of the min-installment member
        uint256 gapPerRound;         // USDC gap covered per round for this slot
        uint256 totalDeployedShares; // YieldRouter shares committed (grows each round)
        uint256 lastAccrualTs;       // timestamp of last interest accrual (0 = never accrued)
    }

    mapping(uint256 circleId => mapping(uint16 slot => GapCoverage)) public gapCoverages;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event Deposited(bytes32 indexed shieldedId, uint256 amount, uint256 lockDuration, uint256 newPoolShares);
    event Withdrawn(bytes32 indexed shieldedId, uint256 amount, uint256 burntPoolShares);
    event SlotCovered(uint256 indexed circleId, uint16 indexed slot, uint256 amount);
    event SlotReleased(uint256 indexed circleId, uint16 indexed slot, uint256 amount);
    event CoverageRateUpdated(uint256 oldBps, uint256 newBps);
    event GapCovered(uint256 indexed circleId, uint16 indexed slot, bytes32 memberId, uint256 gap, uint256 shares);
    event GapDebtSettled(uint256 indexed circleId, uint16 indexed slot, uint256 usdcReleased);
    event InterestAccrued(uint256 indexed circleId, uint16 indexed slot, bytes32 memberId, uint256 amount);
    event InterestForgiven(uint256 indexed circleId, uint16 indexed slot, bytes32 memberId, uint256 amount);

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    error ZeroAmount();
    error InsufficientAvailableCapital(uint256 available, uint256 required);
    error InsufficientWithdrawable(uint256 withdrawable, uint256 requested);
    error SlotNotCovered(uint256 circleId, uint16 slot);
    error GapNotFound(uint256 circleId, uint16 slot);
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
    // Gap coverage (Task 003-02)
    // ──────────────────────────────────────────────

    /// @inheritdoc ISafetyNetPool
    function coverGap(
        uint256 circleId,
        uint16 slot,
        bytes32 memberId,
        uint256 gap
    ) external override nonReentrant {
        if (msg.sender != circle) revert OnlyCircle();
        if (gap == 0) revert ZeroAmount();

        uint256 available = getAvailableCapital();
        if (available < gap) revert InsufficientAvailableCapital(available, gap);

        uint256 sharesCommitted = yieldRouter.convertToShares(gap);

        savingsAccount.addSafetyNetDebt(memberId, sharesCommitted);

        GapCoverage storage gc = gapCoverages[circleId][slot];
        if (gc.lastAccrualTs == 0) {
            // First call for this slot — set fields that only initialise once
            gc.memberId = memberId;
            gc.gapPerRound = gap;
            gc.lastAccrualTs = block.timestamp;
        }
        gc.totalDeployedShares += sharesCommitted;

        totalDeployed += gap;

        emit GapCovered(circleId, slot, memberId, gap, sharesCommitted);
    }

    /// @notice Return the GapCoverage record for a slot.
    function getGapCoverage(uint256 circleId, uint16 slot) external view returns (GapCoverage memory) {
        return gapCoverages[circleId][slot];
    }

    // ──────────────────────────────────────────────
    // Debt settlement (Task 003-03)
    // ──────────────────────────────────────────────

    /// @inheritdoc ISafetyNetPool
    function settleGapDebt(uint256 circleId, uint16 slot) external override nonReentrant {
        if (msg.sender != circle) revert OnlyCircle();

        GapCoverage storage gc = gapCoverages[circleId][slot];
        if (gc.lastAccrualTs == 0) revert GapNotFound(circleId, slot);

        // Auto-accrue any outstanding interest before settlement (must not revert)
        _accrueInterestInternal(circleId, slot);

        uint256 usdcReleased = yieldRouter.convertToAssets(gc.totalDeployedShares);

        // Release the USDC counter (use usdcReleased capped at totalDeployed to avoid underflow)
        totalDeployed = totalDeployed >= usdcReleased ? totalDeployed - usdcReleased : 0;

        delete gapCoverages[circleId][slot];

        emit GapDebtSettled(circleId, slot, usdcReleased);
    }

    /// @inheritdoc ISafetyNetPool
    function convertGapToUsdc(uint256 circleId, uint16 slot) external view override returns (uint256) {
        return yieldRouter.convertToAssets(gapCoverages[circleId][slot].totalDeployedShares);
    }

    // ──────────────────────────────────────────────
    // Interest accrual (Task 003-04)
    // ──────────────────────────────────────────────

    /// @inheritdoc ISafetyNetPool
    function accrueInterest(uint256 circleId, uint16 slot) external override nonReentrant {
        GapCoverage storage gc = gapCoverages[circleId][slot];
        if (gc.lastAccrualTs == 0) return; // slot not tracked / already settled

        if (coverageRateBps == 0) return; // zero rate — no-op (don't consume elapsed window)

        uint256 elapsed = block.timestamp - gc.lastAccrualTs;
        if (elapsed < MIN_ACCRUAL_INTERVAL) return;

        uint256 interest = _computeInterest(gc.totalDeployedShares, elapsed);
        if (interest == 0) return;

        savingsAccount.chargeFromYield(gc.memberId, interest);
        gc.lastAccrualTs = block.timestamp;
        totalInterestCollected += interest;

        emit InterestAccrued(circleId, slot, gc.memberId, interest);
    }

    /// @inheritdoc ISafetyNetPool
    function getAccruedInterest(uint256 circleId, uint16 slot) external view override returns (uint256) {
        GapCoverage storage gc = gapCoverages[circleId][slot];
        if (gc.lastAccrualTs == 0 || coverageRateBps == 0) return 0;
        uint256 elapsed = block.timestamp - gc.lastAccrualTs;
        return _computeInterest(gc.totalDeployedShares, elapsed);
    }

    /// @inheritdoc ISafetyNetPool
    function getEstimatedNetPayout(uint256 circleId, uint16 slot)
        external
        view
        override
        returns (uint256 grossUsdc, uint256 debtUsdc, uint256 interestUsdc, uint256 netUsdc)
    {
        // grossUsdc needs access to SavingsCircle's poolSize — not available here.
        // Caller should combine with circle data. Returned as 0 from the pool's perspective.
        grossUsdc = 0;
        debtUsdc = yieldRouter.convertToAssets(gapCoverages[circleId][slot].totalDeployedShares);
        GapCoverage storage gc = gapCoverages[circleId][slot];
        if (gc.lastAccrualTs != 0 && coverageRateBps != 0) {
            uint256 elapsed = block.timestamp - gc.lastAccrualTs;
            interestUsdc = _computeInterest(gc.totalDeployedShares, elapsed);
        }
        uint256 total = debtUsdc + interestUsdc;
        netUsdc = total >= grossUsdc ? 0 : grossUsdc - total;
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

    /// @dev Compute USDC interest owed on `totalDeployedShares` for `elapsed` seconds.
    function _computeInterest(uint256 shares, uint256 elapsed) internal view returns (uint256) {
        if (shares == 0 || elapsed == 0 || coverageRateBps == 0) return 0;
        uint256 debtUsdc = yieldRouter.convertToAssets(shares);
        return (debtUsdc * coverageRateBps * elapsed) / (10_000 * 365 days);
    }

    /// @dev Auto-accrue interest before settlement. MUST NOT revert — wraps chargeFromYield
    ///      in try/catch so PositionInsolvent does not propagate into claimPayout.
    function _accrueInterestInternal(uint256 circleId, uint16 slot) internal {
        GapCoverage storage gc = gapCoverages[circleId][slot];
        if (gc.lastAccrualTs == 0 || coverageRateBps == 0) return;

        uint256 elapsed = block.timestamp - gc.lastAccrualTs;
        uint256 interest = _computeInterest(gc.totalDeployedShares, elapsed);
        if (interest == 0) return;

        try savingsAccount.chargeFromYield(gc.memberId, interest) {
            gc.lastAccrualTs = block.timestamp;
            totalInterestCollected += interest;
            emit InterestAccrued(circleId, slot, gc.memberId, interest);
        } catch {
            // Position insolvent — interest is forgiven; lastAccrualTs not updated
            emit InterestForgiven(circleId, slot, gc.memberId, interest);
        }
    }
}
