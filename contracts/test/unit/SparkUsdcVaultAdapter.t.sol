// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SparkUsdcVaultAdapter} from "../../src/yield/SparkUsdcVaultAdapter.sol";
import {IYieldSourceAdapter} from "../../src/interfaces/IYieldSourceAdapter.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockUsdcVaultL2} from "../mocks/MockUsdcVaultL2.sol";
import {MockRateProvider} from "../mocks/MockRateProvider.sol";

/// @notice Unit tests for SparkUsdcVaultAdapter — runs against mock vault (no Base Sepolia fork).
///         Fork-based tests can be added separately using $BASE_SEPOLIA_RPC_URL.
contract SparkUsdcVaultAdapterTest is Test {
    SparkUsdcVaultAdapter adapter;
    MockUSDC usdc;
    MockUsdcVaultL2 vault;
    MockRateProvider rateProvider;
    address yieldRouter;
    address owner;

    uint256 constant RAY = 1e27;
    uint256 constant INITIAL_RATE = 1e27; // 1.0 in ray

    function setUp() public {
        owner = makeAddr("owner");
        yieldRouter = makeAddr("yieldRouter");

        usdc = new MockUSDC();
        vault = new MockUsdcVaultL2(address(usdc));
        rateProvider = new MockRateProvider(INITIAL_RATE);

        vm.prank(owner);
        adapter = new SparkUsdcVaultAdapter(
            address(vault),
            address(usdc),
            address(rateProvider),
            yieldRouter
        );

        // Fund yieldRouter with USDC for deposits
        usdc.mint(yieldRouter, 10_000e6);
        vm.prank(yieldRouter);
        usdc.approve(address(adapter), type(uint256).max);
    }

    // ── deposit ──────────────────────────────────────────────────────────────

    function test_deposit_transfersUsdcToVault() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        assertGt(vault.balanceOf(address(adapter)), 0);
        assertApproxEqAbs(adapter.getBalance(), 1000e6, 1);
    }

    function test_deposit_updatesLastRecordedBalance() public {
        vm.prank(yieldRouter);
        adapter.deposit(500e6);

        assertEq(adapter.lastRecordedBalance(), 500e6);
    }

    function test_deposit_revertsIfNotYieldRouter() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert("ONLY_YIELD_ROUTER");
        adapter.deposit(1000e6);
    }

    function test_deposit_revertsZeroAmount() public {
        vm.prank(yieldRouter);
        vm.expectRevert(SparkUsdcVaultAdapter.ZeroAmount.selector);
        adapter.deposit(0);
    }

    function test_deposit_revertsWhenPaused() public {
        vm.prank(yieldRouter);
        adapter.deposit(100e6);

        // Trigger emergency exit to pause adapter
        usdc.mint(address(vault), 100e6); // ensure vault has USDC for exit
        vm.prank(owner);
        adapter.emergencyExit(makeAddr("receiver"));

        vm.prank(yieldRouter);
        vm.expectRevert(SparkUsdcVaultAdapter.AdapterPaused.selector);
        adapter.deposit(100e6);
    }

    // ── getBalance ───────────────────────────────────────────────────────────

    function test_getBalance_returnsUsdc6Decimals() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        uint256 bal = adapter.getBalance();
        assertApproxEqAbs(bal, 1000e6, 1);
    }

    function test_getBalance_increasesWithYield() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(50e6); // simulate 5% yield
        assertGt(adapter.getBalance(), 1000e6);
    }

    // ── harvest ───────────────────────────────────────────────────────────────

    function test_harvest_transfersYieldToYieldRouter() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(10e6);

        uint256 beforeBalance = usdc.balanceOf(yieldRouter);
        vm.prank(yieldRouter);
        uint256 yieldAmount = adapter.harvest();
        uint256 afterBalance = usdc.balanceOf(yieldRouter);

        assertGt(yieldAmount, 0);
        assertEq(afterBalance - beforeBalance, yieldAmount);
    }

    function test_harvest_updatesLastRecordedBalance() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(20e6);

        vm.prank(yieldRouter);
        adapter.harvest();

        // lastRecordedBalance should equal the new principal (no yield remaining)
        assertApproxEqAbs(adapter.lastRecordedBalance(), 1000e6, 1);
    }

    function test_harvest_idempotentWithinSameBlock() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(10e6);

        vm.startPrank(yieldRouter);
        uint256 first = adapter.harvest();
        uint256 second = adapter.harvest(); // same block, no new yield
        vm.stopPrank();

        assertGt(first, 0);
        assertEq(second, 0);
    }

    function test_harvest_updatesRateAndTimestamp() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(10e6);
        rateProvider.setConversionRate(1_05e25); // 1.05 ray

        vm.prank(yieldRouter);
        adapter.harvest();

        assertEq(adapter.lastHarvestRate(), 1_05e25);
        assertEq(adapter.lastHarvestTimestamp(), block.timestamp);
    }

    function test_harvest_revertsIfNotYieldRouter() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(5e6);

        vm.prank(makeAddr("rando"));
        vm.expectRevert("ONLY_YIELD_ROUTER");
        adapter.harvest();
    }

    // ── withdraw ──────────────────────────────────────────────────────────────

    function test_withdraw_returnsUsdcToYieldRouter() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        uint256 before = usdc.balanceOf(yieldRouter);
        vm.prank(yieldRouter);
        adapter.withdraw(500e6);
        uint256 after_ = usdc.balanceOf(yieldRouter);

        assertEq(after_ - before, 500e6);
        assertApproxEqAbs(adapter.lastRecordedBalance(), 500e6, 1);
    }

    function test_withdraw_revertsIfPsmCapInsufficient() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.setPsmCap(100e6); // only 100 USDC available

        vm.prank(yieldRouter);
        vm.expectRevert(
            abi.encodeWithSelector(SparkUsdcVaultAdapter.InsufficientLiquidity.selector, 100e6, 500e6)
        );
        adapter.withdraw(500e6);
    }

    // ── withdrawMax ───────────────────────────────────────────────────────────

    function test_withdrawMax_partialWhenPsmCapped() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.setPsmCap(300e6);

        vm.prank(yieldRouter);
        vm.expectEmit(true, true, false, true);
        emit IYieldSourceAdapter.PartialWithdrawal(500e6, 300e6);
        uint256 withdrawn = adapter.withdrawMax(500e6);

        assertEq(withdrawn, 300e6);
        assertEq(usdc.balanceOf(yieldRouter), 10_000e6 - 1000e6 + 300e6);
    }

    function test_withdrawMax_fullWhenCapNotHit() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vm.prank(yieldRouter);
        uint256 withdrawn = adapter.withdrawMax(500e6);
        assertEq(withdrawn, 500e6);
    }

    // ── getAPY ───────────────────────────────────────────────────────────────

    function test_getAPY_returnsZeroBeforeFirstHarvest() public {
        vm.prank(yieldRouter);
        adapter.deposit(100e6);

        assertEq(adapter.getAPY(), 0);
    }

    function test_getAPY_nonZeroAfterHarvestWindow() public {
        vm.prank(yieldRouter);
        adapter.deposit(1000e6);

        vault.accrueYield(10e6);

        // Set an initial rate and harvest
        rateProvider.setConversionRate(1e27);
        vm.prank(yieldRouter);
        adapter.harvest();

        // Advance 30 days, rate increases ~5%
        vm.warp(block.timestamp + 30 days);
        rateProvider.setConversionRate(1_05e25); // ~5% increase in rate

        assertGt(adapter.getAPY(), 0);
    }

    // ── emergencyExit ─────────────────────────────────────────────────────────

    function test_emergencyExit_revertsIfNotOwner() public {
        vm.prank(yieldRouter);
        adapter.deposit(100e6);

        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        adapter.emergencyExit(makeAddr("receiver"));
    }

    function test_emergencyExit_pausesAdapter() public {
        vm.prank(yieldRouter);
        adapter.deposit(100e6);

        address receiver = makeAddr("receiver");
        vm.prank(owner);
        adapter.emergencyExit(receiver);

        assertTrue(adapter.paused());
    }

    function test_emergencyExit_transfersToReceiver() public {
        vm.prank(yieldRouter);
        adapter.deposit(100e6);

        address receiver = makeAddr("receiver");
        vm.prank(owner);
        adapter.emergencyExit(receiver);

        // After exit, receiver should have the USDC (mock vault returns USDC on exit)
        assertGt(usdc.balanceOf(receiver), 0);
    }

    function test_emergencyExit_emitsEvent() public {
        vm.prank(yieldRouter);
        adapter.deposit(100e6);

        address receiver = makeAddr("receiver");
        uint256 shares = vault.balanceOf(address(adapter));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SparkUsdcVaultAdapter.EmergencyExit(shares, receiver);
        adapter.emergencyExit(receiver);
    }
}
