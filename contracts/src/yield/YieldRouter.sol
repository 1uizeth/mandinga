// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IYieldRouter} from "../interfaces/IYieldRouter.sol";
import {IYieldSourceAdapter} from "../interfaces/IYieldSourceAdapter.sol";

/// @title YieldRouter
/// @notice ERC4626-compliant vault that routes USDC deposits through `SparkUsdcVaultAdapter`
///         (sole adapter in v1). Yield accrues as share price appreciation — no per-position
///         distribution or Merkle-drop required.
///
/// @dev Architecture:
///  - `SavingsAccount` calls `allocate(amount)` — restricted entry point for the savings layer.
///  - `SafetyNetPool` calls standard ERC4626 `deposit()`/`withdraw()` — unrestricted.
///  - `harvest()` is permissionless; distributes fee to treasury and buffer to CircleBuffer;
///    net yield stays in the pool raising `totalAssets()` and every share's USDC value.
///  - Circuit breaker: if APY drops > 50% vs previous harvest, new deposits/harvest are paused.
///
/// @dev Share accounting: shares are stored as `uint256` inside SavingsAccount and SafetyNetPool.
///      No ERC20 share token is issued to external callers — `transfer()` and `transferFrom()`
///      work on the ERC20 minted to the depositing contract (SavingsAccount / SafetyNetPool).
contract YieldRouter is IYieldRouter, ERC4626, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    // Constants
    // ──────────────────────────────────────────────

    uint256 public constant MAX_FEE_BPS = 2000;   // 20% hard ceiling
    uint256 public constant MAX_BUFFER_BPS = 1000; // 10% hard ceiling
    uint256 public constant HARVEST_COOLDOWN = 5 minutes;

    // ──────────────────────────────────────────────
    // Immutables
    // ──────────────────────────────────────────────

    /// @notice Sole yield adapter in v1 (SparkUsdcVaultAdapter).
    IYieldSourceAdapter public immutable sparkAdapter;

    /// @notice SavingsAccount — the only contract allowed to call `allocate()`.
    address public immutable savingsAccount;

    /// @notice CircleBuffer — receives `bufferRateBps` share of each harvest.
    address public immutable circleBuffer;

    /// @notice Protocol treasury — receives `feeRateBps` share of each harvest.
    address public immutable treasury;

    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    /// @notice Protocol fee rate in basis points. Default 1000 (10%).
    uint256 public feeRateBps;

    /// @notice Circle buffer contribution rate in basis points. Default 500 (5%).
    uint256 public bufferRateBps;

    /// @notice Whether the circuit breaker is currently active (new deposits/harvest paused).
    bool public circuitBreakerTripped;

    /// @notice APY (bps) recorded at the previous harvest — used for the 50% drop check.
    uint256 public lastHarvestApyBps;

    /// @notice Timestamp of the last successful harvest — enforces cooldown window.
    uint256 public lastHarvestTimestamp;

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    // CircuitBreakerActive() is inherited from IYieldRouter
    error HarvestCooldownActive(uint256 nextAllowedAt);
    error OnlySavingsAccount();
    error ZeroAmount();
    error FeeTooHigh(uint256 requested, uint256 max);
    error BufferTooHigh(uint256 requested, uint256 max);

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlySavingsAccount() {
        if (msg.sender != savingsAccount) revert OnlySavingsAccount();
        _;
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /// @param _usdc          USDC token address (ERC4626 asset)
    /// @param _sparkAdapter  SparkUsdcVaultAdapter address
    /// @param _savingsAccount SavingsAccount — sole caller of `allocate()`
    /// @param _circleBuffer  CircleBuffer contract (receives buffer yield)
    /// @param _treasury      Protocol treasury (receives fee)
    constructor(
        address _usdc,
        address _sparkAdapter,
        address _savingsAccount,
        address _circleBuffer,
        address _treasury
    )
        ERC4626(IERC20(_usdc))
        ERC20("Mandinga Yield Router", "mYRT")
        Ownable(msg.sender)
    {
        sparkAdapter = IYieldSourceAdapter(_sparkAdapter);
        savingsAccount = _savingsAccount;
        circleBuffer = _circleBuffer;
        treasury = _treasury;
        feeRateBps = 1000;   // 10%
        bufferRateBps = 500; // 5%
    }

    // ──────────────────────────────────────────────
    // ERC4626 overrides — access control + adapter routing
    // ──────────────────────────────────────────────

    /// @notice Aggregates idle USDC in the router plus all capital deployed in the adapter.
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        return idle + sparkAdapter.getBalance();
    }

    /// @dev Called by ERC4626 after receiving USDC and minting shares.
    ///      Routes the deposited USDC to the spark adapter.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
    {
        if (circuitBreakerTripped) revert CircuitBreakerActive();
        super._deposit(caller, receiver, assets, shares); // pulls USDC into YieldRouter, mints shares
        IERC20(asset()).forceApprove(address(sparkAdapter), assets);
        sparkAdapter.deposit(assets);
        emit CapitalAllocated(assets, block.timestamp);
    }

    /// @dev Called by ERC4626 before burning shares and transferring USDC.
    ///      Pulls required USDC back from the spark adapter first.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        _pullFromAdapter(assets);
        super._withdraw(caller, receiver, owner, assets, shares); // burns shares, transfers USDC
        emit CapitalWithdrawn(assets, block.timestamp);
    }

    /// @notice Standard ERC4626 deposit — used by SafetyNetPool and other protocol contracts.
    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    /// @notice Standard ERC4626 withdraw — used by SavingsAccount and SafetyNetPool.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @notice Standard ERC4626 mint — available for protocol use.
    function mint(uint256 shares, address receiver)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.mint(shares, receiver);
    }

    /// @notice Standard ERC4626 redeem — available for protocol use.
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626, IERC4626)
        nonReentrant
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    // ──────────────────────────────────────────────
    // IYieldRouter protocol-specific functions
    // ──────────────────────────────────────────────

    /// @inheritdoc IYieldRouter
    /// @dev Restricted to SavingsAccount. USDC must be pre-approved to this contract.
    ///      Mints shares to the SavingsAccount (msg.sender).
    function allocate(uint256 amount) external override onlySavingsAccount nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (circuitBreakerTripped) revert CircuitBreakerActive();
        uint256 shares = previewDeposit(amount);
        _deposit(msg.sender, msg.sender, amount, shares);
    }

    /// @inheritdoc IYieldRouter
    /// @dev Permissionless — callable by anyone (MEV bots, keepers, protocol).
    ///      Enforces 5-minute cooldown. When APY drops > 50%, sets circuit breaker flag,
    ///      emits `CircuitBreakerTripped`, and returns early without harvesting yield.
    ///      Subsequent calls with the flag active revert with `CircuitBreakerActive`.
    function harvest() external override nonReentrant {
        if (circuitBreakerTripped) revert CircuitBreakerActive();

        if (block.timestamp < lastHarvestTimestamp + HARVEST_COOLDOWN) {
            revert HarvestCooldownActive(lastHarvestTimestamp + HARVEST_COOLDOWN);
        }

        // Circuit breaker: if APY drops > 50% vs last harvest, pause future harvests/deposits.
        // We set the flag and return — EVM reverts undo state, so we must NOT revert here.
        uint256 currentApyBps = sparkAdapter.getAPY();
        if (lastHarvestApyBps > 0 && currentApyBps < lastHarvestApyBps / 2) {
            circuitBreakerTripped = true;
            lastHarvestTimestamp = block.timestamp;
            emit CircuitBreakerTripped("APY dropped > 50%", block.timestamp);
            return; // exit without harvesting; future calls revert CircuitBreakerActive
        }

        uint256 grossYield = sparkAdapter.harvest();
        lastHarvestTimestamp = block.timestamp;
        if (grossYield == 0) {
            return;
        }

        uint256 fee = grossYield * feeRateBps / 10_000;
        uint256 bufferContribution = grossYield * bufferRateBps / 10_000;
        uint256 netYield = grossYield - fee - bufferContribution;

        // Transfer fee to treasury (leaves pool, reducing totalAssets).
        if (fee > 0) {
            IERC20(asset()).safeTransfer(treasury, fee);
        }

        // Transfer buffer contribution to CircleBuffer (leaves pool).
        if (bufferContribution > 0) {
            IERC20(asset()).safeTransfer(circleBuffer, bufferContribution);
        }

        // Net yield stays in the pool — totalAssets() grows, share price appreciates automatically.

        if (currentApyBps > 0) lastHarvestApyBps = currentApyBps;

        emit YieldHarvested(grossYield, fee, bufferContribution, netYield, block.timestamp);
    }

    /// @inheritdoc IYieldRouter
    function getBlendedAPY() external view override returns (uint256) {
        return sparkAdapter.getAPY();
    }

    /// @inheritdoc IYieldRouter
    function getCircuitBreakerStatus() external view override returns (bool) {
        return circuitBreakerTripped;
    }

    /// @inheritdoc IYieldRouter
    function getTotalAllocated() external view override returns (uint256) {
        return totalAssets();
    }

    // ──────────────────────────────────────────────
    // Governance
    // ──────────────────────────────────────────────

    /// @notice Reset circuit breaker after governance review.
    function resetCircuitBreaker() external onlyOwner {
        circuitBreakerTripped = false;
        emit CircuitBreakerReset(block.timestamp);
    }

    /// @notice Update protocol fee rate.
    /// @param newRateBps New fee in basis points (max 2000 = 20%)
    function setFeeRate(uint256 newRateBps) external onlyOwner {
        if (newRateBps > MAX_FEE_BPS) revert FeeTooHigh(newRateBps, MAX_FEE_BPS);
        feeRateBps = newRateBps;
    }

    /// @notice Update buffer contribution rate.
    /// @param newRateBps New buffer rate in basis points (max 1000 = 10%)
    function setBufferRate(uint256 newRateBps) external onlyOwner {
        if (newRateBps > MAX_BUFFER_BPS) revert BufferTooHigh(newRateBps, MAX_BUFFER_BPS);
        bufferRateBps = newRateBps;
    }

    /// @notice Return fee config for public dashboard (AC-005-3).
    function getFeeInfo()
        external
        view
        returns (uint256 feeRate, uint256 bufferRate, address treasuryAddr)
    {
        return (feeRateBps, bufferRateBps, treasury);
    }

    // ──────────────────────────────────────────────
    // Internal helpers
    // ──────────────────────────────────────────────

    /// @dev Pull `assets` USDC from the sparkAdapter into this contract.
    ///      Falls back to `withdrawMax()` if PSM liquidity is capped.
    function _pullFromAdapter(uint256 assets) internal {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        if (idle >= assets) return; // enough idle USDC — no adapter call needed
        uint256 needed = assets - idle;
        try sparkAdapter.withdraw(needed) {
            // full amount retrieved
        } catch {
            sparkAdapter.withdrawMax(needed); // partial — remainder stays in adapter
        }
    }
}
