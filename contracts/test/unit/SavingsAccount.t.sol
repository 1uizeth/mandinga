// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {SavingsAccount} from "../../src/core/SavingsAccount.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";

contract MockUSDC is IERC20 {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;

    mapping(address => uint256) private _bal;
    mapping(address => mapping(address => uint256)) private _allowance;

    function mint(address to, uint256 amount) external {
        _bal[to] += amount;
    }

    function totalSupply() external pure returns (uint256) {
        return type(uint256).max;
    }

    function balanceOf(address a) external view returns (uint256) {
        return _bal[a];
    }

    function allowance(address o, address s) external view returns (uint256) {
        return _allowance[o][s];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _bal[msg.sender] -= amount;
        _bal[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (_allowance[from][msg.sender] != type(uint256).max) {
            _allowance[from][msg.sender] -= amount;
        }
        _bal[from] -= amount;
        _bal[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract MockYieldRouter is IYieldRouter {
    MockUSDC public usdc;
    uint256 public totalAllocated;

    constructor(address _usdc) {
        usdc = MockUSDC(_usdc);
    }

    // ── IYieldRouter protocol functions ──

    function allocate(uint256 amount) external override {
        // Pull USDC from the caller (SavingsAccount)
        usdc.transferFrom(msg.sender, address(this), amount);
        totalAllocated += amount;
    }

    function harvest() external override {}

    function getBlendedAPY() external pure override returns (uint256) {
        return 500; // 5% in bps
    }

    function getCircuitBreakerStatus() external pure override returns (bool) {
        return false;
    }

    function getTotalAllocated() external view override returns (uint256) {
        return totalAllocated;
    }

    // ── IERC4626 (inherited) ── minimal stubs ──

    function asset() external view override returns (address) {
        return address(usdc);
    }

    function totalAssets() external view override returns (uint256) {
        return totalAllocated;
    }

    function convertToShares(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) external view override returns (uint256) {
        return totalAllocated;
    }

    function maxRedeem(address owner) external view override returns (uint256) {
        return totalAllocated;
    }

    function previewDeposit(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function previewMint(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function previewWithdraw(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function previewRedeem(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        usdc.transferFrom(msg.sender, address(this), assets);
        totalAllocated += assets;
        emit Deposit(msg.sender, receiver, assets, assets);
        return assets;
    }

    function mint(uint256 shares, address receiver) external override returns (uint256) {
        usdc.transferFrom(msg.sender, address(this), shares);
        totalAllocated += shares;
        emit Deposit(msg.sender, receiver, shares, shares);
        return shares;
    }

    /// @dev ERC4626 withdraw: burns `assets` worth of shares from `owner`, sends USDC to `receiver`.
    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        totalAllocated -= assets;
        usdc.transfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, assets);
        return assets;
    }

    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        totalAllocated -= shares;
        usdc.transfer(receiver, shares);
        emit Withdraw(msg.sender, receiver, owner, shares, shares);
        return shares;
    }

    function name() external pure override returns (string memory) {
        return "Mock YieldRouter";
    }

    function symbol() external pure override returns (string memory) {
        return "MYR";
    }

    function decimals() external pure override returns (uint8) {
        return 6;
    }

    function totalSupply() external pure override returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure override returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reentrant attacker contract
// ─────────────────────────────────────────────────────────────────────────────

/// @dev Attempts reentrant withdrawal during the ERC4626 withdraw callback.
contract ReentrantAttacker {
    SavingsAccount public target;
    MockUSDC public usdc;
    bool private _attacking;

    constructor(address _target, address _usdc) {
        target = SavingsAccount(_target);
        usdc = MockUSDC(_usdc);
    }

    function attack(uint256 depositAmount) external {
        usdc.approve(address(target), type(uint256).max);
        target.deposit(depositAmount);
        _attacking = true;
        // Try to withdraw — reentrancy guard should block the second call
        target.withdraw(depositAmount / 2);
    }

    // Called by MockUSDC.transfer during the withdraw path (simulated via fallback)
    receive() external payable {
        if (_attacking) {
            _attacking = false;
            target.withdraw(100e6);
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test suite
// ─────────────────────────────────────────────────────────────────────────────

contract SavingsAccountTest is Test {
    // ── Local event copies for vm.expectEmit (interface events can't be emitted externally) ──
    event Deposited(bytes32 indexed shieldedId, uint256 amount);
    event Withdrawn(bytes32 indexed shieldedId, uint256 amount);
    event ObligationSet(bytes32 indexed shieldedId, uint256 newObligation);

    MockUSDC internal usdc;
    MockYieldRouter internal router;
    SavingsAccount internal sa;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal emergencyModule = makeAddr("emergencyModule");
    address internal savingsCircle = makeAddr("savingsCircle");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant DEPOSIT_1K = 1_000e6;
    uint256 internal constant DEPOSIT_500 = 500e6;

    function setUp() public {
        usdc = new MockUSDC();
        router = new MockYieldRouter(address(usdc));
        sa = new SavingsAccount(IYieldRouter(address(router)), emergencyModule, savingsCircle, address(usdc));

        // Fund the router with USDC so it can service withdrawals
        usdc.mint(address(router), 100_000e6);

        // Fund test actors
        usdc.mint(alice, 10_000e6);
        usdc.mint(bob, 10_000e6);
    }

    // ──────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────

    function _depositAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        usdc.approve(address(sa), amount);
        sa.deposit(amount);
        vm.stopPrank();
    }

    function _shieldedId(address user) internal view returns (bytes32) {
        return sa.computeShieldedId(user);
    }

    // ──────────────────────────────────────────────
    // Deposit tests
    // ──────────────────────────────────────────────

    function test_deposit_balanceReflectsDeposit() public {
        _depositAs(alice, DEPOSIT_1K);

        ISavingsAccount.Position memory pos = sa.getPosition(_shieldedId(alice));
        assertEq(pos.balance, DEPOSIT_1K, "balance should equal deposit");
        assertEq(pos.circleObligation, 0);
        assertEq(pos.yieldEarnedTotal, 0);
    }

    function test_deposit_emitsDepositedEvent() public {
        bytes32 id = _shieldedId(alice);

        vm.startPrank(alice);
        usdc.approve(address(sa), DEPOSIT_1K);

        vm.expectEmit(true, false, false, true);
        emit Deposited(id, DEPOSIT_1K);
        sa.deposit(DEPOSIT_1K);
        vm.stopPrank();
    }

    function test_deposit_revertsOnZeroAmount() public {
        vm.startPrank(alice);
        usdc.approve(address(sa), 0);
        vm.expectRevert(SavingsAccount.ZeroAmount.selector);
        sa.deposit(0);
        vm.stopPrank();
    }

    // ──────────────────────────────────────────────
    // Withdraw — free balance
    // ──────────────────────────────────────────────

    function test_withdraw_freeBalance_succeeds() public {
        _depositAs(alice, DEPOSIT_1K);

        uint256 balBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        sa.withdraw(DEPOSIT_500);

        assertEq(usdc.balanceOf(alice), balBefore + DEPOSIT_500, "alice should receive USDC");

        ISavingsAccount.Position memory pos = sa.getPosition(_shieldedId(alice));
        assertEq(pos.balance, DEPOSIT_1K - DEPOSIT_500);
    }

    function test_withdraw_emitsWithdrawnEvent() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(id, DEPOSIT_500);

        vm.prank(alice);
        sa.withdraw(DEPOSIT_500);
    }

    // ──────────────────────────────────────────────
    // Withdraw — locked balance
    // ──────────────────────────────────────────────

    function test_withdraw_lockedBalance_reverts() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        // Lock the full balance
        vm.prank(savingsCircle);
        sa.setCircleObligation(id, DEPOSIT_1K);

        // Trying to withdraw any amount should revert
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ISavingsAccount.InsufficientWithdrawableBalance.selector, DEPOSIT_500, 0)
        );
        sa.withdraw(DEPOSIT_500);
    }

    function test_withdraw_partiallyLocked_withdrawsFreePortionOnly() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        // Lock half
        vm.prank(savingsCircle);
        sa.setCircleObligation(id, DEPOSIT_500);

        // Can withdraw up to free 500
        vm.prank(alice);
        sa.withdraw(DEPOSIT_500);

        ISavingsAccount.Position memory pos = sa.getPosition(id);
        assertEq(pos.balance, DEPOSIT_500, "locked portion should remain");
    }

    // ──────────────────────────────────────────────
    // setCircleObligation
    // ──────────────────────────────────────────────

    function test_setCircleObligation_nonSavingsCircle_reverts() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISavingsAccount.NotAuthorized.selector, attacker, savingsCircle)
        );
        sa.setCircleObligation(id, DEPOSIT_500);
    }

    function test_setCircleObligation_exceedingBalance_reverts() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(savingsCircle);
        vm.expectRevert(
            abi.encodeWithSelector(ISavingsAccount.PrincipalLockViolation.selector, DEPOSIT_1K, DEPOSIT_1K + 1)
        );
        sa.setCircleObligation(id, DEPOSIT_1K + 1);
    }

    function test_setCircleObligation_emitsObligationSet() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.expectEmit(true, false, false, true);
        emit ObligationSet(id, DEPOSIT_500);

        vm.prank(savingsCircle);
        sa.setCircleObligation(id, DEPOSIT_500);
    }

    function test_getCircleObligation_returnsCorrectValue() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(savingsCircle);
        sa.setCircleObligation(id, DEPOSIT_500);

        assertEq(sa.getCircleObligation(id), DEPOSIT_500);
    }

    // ──────────────────────────────────────────────
    // creditYield
    // ──────────────────────────────────────────────

    function test_creditYield_onlyYieldRouter() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISavingsAccount.NotAuthorized.selector, attacker, address(router))
        );
        sa.creditYield(id, 100e6);
    }

    function test_creditYield_updatesBalance() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(address(router));
        sa.creditYield(id, 50e6);

        ISavingsAccount.Position memory pos = sa.getPosition(id);
        assertEq(pos.balance, DEPOSIT_1K + 50e6);
        assertEq(pos.yieldEarnedTotal, 50e6);
    }

    function test_creditYield_zeroAmountIsNoop() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(address(router));
        sa.creditYield(id, 0); // should not revert

        assertEq(sa.getPosition(id).balance, DEPOSIT_1K);
    }

    // ──────────────────────────────────────────────
    // Emergency
    // ──────────────────────────────────────────────

    function test_activateEmergency_nonModule_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISavingsAccount.NotAuthorized.selector, attacker, emergencyModule)
        );
        sa.activateEmergency();
    }

    function test_activateEmergency_setsFlag() public {
        assertFalse(sa.emergencyActive());
        vm.prank(emergencyModule);
        sa.activateEmergency();
        assertTrue(sa.emergencyActive());
    }

    function test_emergencyWithdraw_returnsFullBalance_includingLocked() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        // Lock half before emergency
        vm.prank(savingsCircle);
        sa.setCircleObligation(id, DEPOSIT_500);

        // Activate emergency
        vm.prank(emergencyModule);
        sa.activateEmergency();

        uint256 balBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        sa.emergencyWithdraw();

        // Full 1000 USDC returned, including locked 500
        assertEq(usdc.balanceOf(alice), balBefore + DEPOSIT_1K, "full balance including locked should be returned");

        ISavingsAccount.Position memory pos = sa.getPosition(id);
        assertEq(pos.balance, 0);
        assertEq(pos.circleObligation, 0);
        assertTrue(pos.emergencyExit);
    }

    function test_emergencyWithdraw_withoutEmergency_reverts() public {
        _depositAs(alice, DEPOSIT_1K);

        vm.prank(alice);
        vm.expectRevert(ISavingsAccount.EmergencyNotActive.selector);
        sa.emergencyWithdraw();
    }

    function test_emergencyWithdraw_cannotExitTwice() public {
        _depositAs(alice, DEPOSIT_1K);

        vm.prank(emergencyModule);
        sa.activateEmergency();

        vm.prank(alice);
        sa.emergencyWithdraw();

        // Second call should revert
        vm.prank(alice);
        vm.expectRevert(SavingsAccount.PositionAlreadyExited.selector);
        sa.emergencyWithdraw();
    }

    // ──────────────────────────────────────────────
    // View helpers
    // ──────────────────────────────────────────────

    function test_getWithdrawableBalance_noObligation() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);
        assertEq(sa.getWithdrawableBalance(id), DEPOSIT_1K);
    }

    function test_getWithdrawableBalance_withObligation() public {
        _depositAs(alice, DEPOSIT_1K);
        bytes32 id = _shieldedId(alice);

        vm.prank(savingsCircle);
        sa.setCircleObligation(id, DEPOSIT_500);

        assertEq(sa.getWithdrawableBalance(id), DEPOSIT_500);
    }

    function test_getPosition_unknownId_returnsZeroStruct() public view {
        bytes32 unknownId = keccak256("unknown");
        ISavingsAccount.Position memory pos = sa.getPosition(unknownId);
        assertEq(pos.balance, 0);
        assertEq(pos.circleObligation, 0);
        assertFalse(pos.emergencyExit);
    }

    // ──────────────────────────────────────────────
    // Multi-user isolation
    // ──────────────────────────────────────────────

    function test_multipleUsers_positionsIsolated() public {
        _depositAs(alice, DEPOSIT_1K);
        _depositAs(bob, DEPOSIT_500);

        bytes32 idA = _shieldedId(alice);
        bytes32 idB = _shieldedId(bob);

        assertEq(sa.getPosition(idA).balance, DEPOSIT_1K);
        assertEq(sa.getPosition(idB).balance, DEPOSIT_500);

        // Lock alice, bob should be unaffected
        vm.prank(savingsCircle);
        sa.setCircleObligation(idA, DEPOSIT_1K);

        assertEq(sa.getWithdrawableBalance(idA), 0);
        assertEq(sa.getWithdrawableBalance(idB), DEPOSIT_500);
    }
}
