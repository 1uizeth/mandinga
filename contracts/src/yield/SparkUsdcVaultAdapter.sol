// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IYieldSourceAdapter} from "../interfaces/IYieldSourceAdapter.sol";

/// @notice Minimal ERC4626 extension with Sky-specific escape hatch.
interface IUsdcVaultL2 is IERC4626 {
    /// @notice Bypass PSM and transfer raw sUSDS to receiver.
    /// @dev Emergency path only — callable by adapter owner when PSM is unavailable.
    function exit(uint256 shares, address receiver, address owner) external returns (uint256);
}

/// @notice Sky Protocol rate provider — yields a ray (1e27) conversion rate.
interface IRateProvider {
    function getConversionRate() external view returns (uint256);
}

/// @title SparkUsdcVaultAdapter
/// @notice Yield source adapter wrapping the Sky Savings Rate (`UsdcVaultL2` on Base).
///         Deposits USDC via PSM3 into sUSDS; yield accrues as `rateProvider.getConversionRate()`
///         appreciates over time. Implements `IYieldSourceAdapter` for consumption by `YieldRouter`.
///
/// @dev Decimal handling: `UsdcVaultL2.convertToAssets(shares)` always returns 6-decimal USDC.
///      The 1e12 sUSDS↔USDC mismatch is resolved inside PSM math — no normalisation required here.
///
/// @dev Liquidity cap: `vault.maxWithdraw(address(this))` is bounded by USDC in the PSM pocket.
///      Large withdrawals must use `withdrawMax()` as a partial-withdrawal fallback.
contract SparkUsdcVaultAdapter is IYieldSourceAdapter, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    // Immutables
    // ──────────────────────────────────────────────

    /// @notice UsdcVaultL2 proxy (permanent — immune to Sky governance upgrades).
    IUsdcVaultL2 public immutable vault;

    /// @notice USDC stablecoin (6 decimals).
    IERC20 public immutable usdc;

    /// @notice Sky rate provider — used to compute APY from conversion rate delta.
    IRateProvider public immutable rateProvider;

    /// @notice The YieldRouter that owns this adapter.
    address public immutable yieldRouter;

    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    /// @notice Last USDC balance snapshot recorded after a deposit, withdraw, or harvest.
    uint256 public lastRecordedBalance;

    /// @notice Conversion rate (ray) recorded at the end of the previous harvest.
    uint256 public lastHarvestRate;

    /// @notice Timestamp of the last harvest.
    uint256 public lastHarvestTimestamp;

    /// @notice When true, `deposit()` and `harvest()` revert. Set by `emergencyExit()`.
    bool public paused;

    // ──────────────────────────────────────────────
    // Constants
    // ──────────────────────────────────────────────

    uint256 private constant SECONDS_PER_YEAR = 365 days;

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    /// @notice Withdrawal amount exceeds PSM pocket liquidity.
    error InsufficientLiquidity(uint256 available, uint256 requested);

    /// @notice Called when adapter is in emergency-paused state.
    error AdapterPaused();

    /// @notice Called with a zero amount.
    error ZeroAmount();

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    /// @notice Emitted after a successful yield harvest.
    event YieldHarvested(uint256 yieldAmount, uint256 timestamp);

    // PartialWithdrawal(uint256 requested, uint256 withdrawn) is inherited from IYieldSourceAdapter

    /// @notice Emitted when the emergency escape hatch is triggered.
    event EmergencyExit(uint256 sharesRedeemed, address receiver);

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlyYieldRouter() {
        require(msg.sender == yieldRouter, "ONLY_YIELD_ROUTER");
        _;
    }

    modifier notPaused() {
        if (paused) revert AdapterPaused();
        _;
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /// @param _vault       UsdcVaultL2 proxy address
    /// @param _usdc        USDC token address (6 dec)
    /// @param _rateProvider Sky rate provider address
    /// @param _yieldRouter  YieldRouter address (sole caller for fund-moving functions)
    constructor(
        address _vault,
        address _usdc,
        address _rateProvider,
        address _yieldRouter
    ) Ownable(msg.sender) {
        vault = IUsdcVaultL2(_vault);
        usdc = IERC20(_usdc);
        rateProvider = IRateProvider(_rateProvider);
        yieldRouter = _yieldRouter;
    }

    // ──────────────────────────────────────────────
    // IYieldSourceAdapter — fund-moving
    // ──────────────────────────────────────────────

    /// @inheritdoc IYieldSourceAdapter
    /// @dev YieldRouter must approve this adapter for `amount` USDC before calling.
    function deposit(uint256 amount) external override onlyYieldRouter nonReentrant notPaused {
        if (amount == 0) revert ZeroAmount();
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.forceApprove(address(vault), amount);
        vault.deposit(amount, address(this));
        lastRecordedBalance += amount;
    }

    /// @inheritdoc IYieldSourceAdapter
    /// @dev Reverts with `InsufficientLiquidity` if PSM pocket has less than `amount` USDC.
    ///      Use `withdrawMax()` as a fallback for partial withdrawal.
    function withdraw(uint256 amount) external override onlyYieldRouter nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 available = vault.maxWithdraw(address(this));
        if (available < amount) revert InsufficientLiquidity(available, amount);
        vault.withdraw(amount, yieldRouter, address(this));
        lastRecordedBalance -= amount;
    }

    /// @inheritdoc IYieldSourceAdapter
    /// @dev Withdraws up to `vault.maxWithdraw(this)`; emits `PartialWithdrawal` if capped.
    function withdrawMax(uint256 requested)
        external
        override
        onlyYieldRouter
        nonReentrant
        returns (uint256 withdrawn)
    {
        if (requested == 0) revert ZeroAmount();
        uint256 available = vault.maxWithdraw(address(this));
        withdrawn = available < requested ? available : requested;
        if (withdrawn == 0) return 0;
        vault.withdraw(withdrawn, yieldRouter, address(this));
        lastRecordedBalance -= withdrawn;
        if (withdrawn < requested) emit PartialWithdrawal(requested, withdrawn);
    }

    /// @inheritdoc IYieldSourceAdapter
    /// @dev Transfers `yieldAmount` USDC to yieldRouter. Updates `lastRecordedBalance`.
    function harvest()
        external
        override
        onlyYieldRouter
        nonReentrant
        notPaused
        returns (uint256 yieldAmount)
    {
        uint256 currentBalance = vault.convertToAssets(vault.balanceOf(address(this)));
        if (currentBalance <= lastRecordedBalance) return 0;

        yieldAmount = currentBalance - lastRecordedBalance;

        // Respect PSM liquidity cap — partial harvest defers remainder to next cycle.
        uint256 available = vault.maxWithdraw(address(this));
        if (available < yieldAmount) {
            emit PartialWithdrawal(yieldAmount, available);
            yieldAmount = available;
        }

        if (yieldAmount == 0) return 0;

        vault.withdraw(yieldAmount, yieldRouter, address(this));

        // After withdrawing yield, principal remains in vault.
        lastRecordedBalance = currentBalance - yieldAmount;
        lastHarvestRate = rateProvider.getConversionRate();
        lastHarvestTimestamp = block.timestamp;

        emit YieldHarvested(yieldAmount, block.timestamp);
    }

    // ──────────────────────────────────────────────
    // IYieldSourceAdapter — view
    // ──────────────────────────────────────────────

    /// @inheritdoc IYieldSourceAdapter
    /// @dev Returns USDC (6 dec) via `convertToAssets()` — no custom normalisation needed.
    function getBalance() external view override returns (uint256) {
        return vault.convertToAssets(vault.balanceOf(address(this)));
    }

    /// @inheritdoc IYieldSourceAdapter
    /// @dev Annualised rate derived from rateProvider.getConversionRate() delta.
    ///      Returns 0 before the first harvest window.
    ///      rate is a ray (1e27); APY bps = (Δrate / lastRate) * (SECONDS_PER_YEAR / elapsed) * 10_000
    function getAPY() external view override returns (uint256) {
        if (lastHarvestRate == 0 || lastHarvestTimestamp == 0) return 0;
        uint256 currentRate = rateProvider.getConversionRate();
        if (currentRate <= lastHarvestRate) return 0;
        uint256 elapsed = block.timestamp - lastHarvestTimestamp;
        if (elapsed == 0) return 0;
        return (currentRate - lastHarvestRate) * SECONDS_PER_YEAR * 10_000 / (lastHarvestRate * elapsed);
    }

    /// @inheritdoc IYieldSourceAdapter
    function getAsset() external view override returns (address) {
        return address(usdc);
    }

    // ──────────────────────────────────────────────
    // Emergency escape hatch
    // ──────────────────────────────────────────────

    /// @notice Bypass PSM and transfer all sUSDS shares directly to `receiver`.
    /// @dev Governance-only. Use when PSM is permanently unavailable.
    ///      Sets adapter to `paused` — subsequent `deposit()` and `harvest()` revert.
    /// @param receiver Address to receive raw sUSDS shares
    function emergencyExit(address receiver) external onlyOwner nonReentrant {
        uint256 shares = vault.balanceOf(address(this));
        vault.exit(shares, receiver, address(this));
        lastRecordedBalance = 0;
        paused = true;
        emit EmergencyExit(shares, receiver);
    }
}
