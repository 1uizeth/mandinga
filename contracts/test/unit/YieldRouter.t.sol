// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YieldRouter} from "../../src/yield/YieldRouter.sol";
import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockSparkAdapter} from "../mocks/MockSparkAdapter.sol";

contract YieldRouterTest is Test {
    YieldRouter router;
    MockUSDC usdc;
    MockSparkAdapter adapter;
    address savingsAccount;
    address circleBuffer;
    address treasury;
    address owner;

    function setUp() public {
        owner = makeAddr("owner");
        savingsAccount = makeAddr("savingsAccount");
        circleBuffer = makeAddr("circleBuffer");
        treasury = makeAddr("treasury");

        usdc = new MockUSDC();

        vm.prank(owner);
        router = new YieldRouter(
            address(usdc),
            address(0), // placeholder — we set adapter via constructor; use a dummy first
            savingsAccount,
            circleBuffer,
            treasury
        );

        // Deploy mock adapter pointing at router
        adapter = new MockSparkAdapter(address(usdc), address(router));

        // Re-deploy router with real adapter
        vm.prank(owner);
        router = new YieldRouter(
            address(usdc),
            address(adapter),
            savingsAccount,
            circleBuffer,
            treasury
        );

        // Fund savingsAccount with USDC
        usdc.mint(savingsAccount, 10_000e6);
        vm.prank(savingsAccount);
        usdc.approve(address(router), type(uint256).max);
    }

    // ── allocate (SavingsAccount entry point) ────────────────────────────────

    function test_allocate_mintsSharesAndRoutesToAdapter() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        // SavingsAccount should hold shares
        assertGt(router.balanceOf(savingsAccount), 0);
        // Adapter received USDC
        assertEq(adapter.balance(), 1000e6);
    }

    function test_allocate_revertsIfNotSavingsAccount() public {
        address other = makeAddr("other");
        usdc.mint(other, 1000e6);
        vm.prank(other);
        usdc.approve(address(router), type(uint256).max);

        vm.prank(other);
        vm.expectRevert(YieldRouter.OnlySavingsAccount.selector);
        router.allocate(1000e6);
    }

    function test_allocate_revertsZeroAmount() public {
        vm.prank(savingsAccount);
        vm.expectRevert(YieldRouter.ZeroAmount.selector);
        router.allocate(0);
    }

    function test_allocate_revertsWhenCircuitBreakerActive() public {
        // Need an initial deposit so harvest records a non-zero APY baseline
        vm.prank(savingsAccount);
        router.allocate(1000e6);
        _tripCircuitBreaker();

        vm.prank(savingsAccount);
        vm.expectRevert(IYieldRouter.CircuitBreakerActive.selector);
        router.allocate(500e6);
    }

    // ── deposit (SafetyNetPool / unrestricted ERC4626) ────────────────────────

    function test_deposit_routesToAdapter() public {
        address snPool = makeAddr("snPool");
        usdc.mint(snPool, 500e6);
        vm.prank(snPool);
        usdc.approve(address(router), type(uint256).max);

        vm.prank(snPool);
        router.deposit(500e6, snPool);

        assertGt(router.balanceOf(snPool), 0);
        assertEq(adapter.balance(), 500e6);
    }

    // ── withdraw ──────────────────────────────────────────────────────────────

    function test_withdraw_returnsUsdcFromAdapter() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        uint256 before = usdc.balanceOf(savingsAccount);
        vm.prank(savingsAccount);
        router.withdraw(500e6, savingsAccount, savingsAccount);
        uint256 after_ = usdc.balanceOf(savingsAccount);

        assertEq(after_ - before, 500e6);
        assertEq(adapter.balance(), 500e6);
    }

    function test_withdraw_worksEvenWhenCircuitBreakerActive() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        _tripCircuitBreaker();

        uint256 balanceAfterTrip = usdc.balanceOf(savingsAccount);

        // Withdrawal should still succeed
        vm.prank(savingsAccount);
        router.withdraw(300e6, savingsAccount, savingsAccount);

        assertEq(usdc.balanceOf(savingsAccount), balanceAfterTrip + 300e6);
    }

    function test_withdraw_fallsBackToWithdrawMaxOnPsmCap() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        // Make adapter's withdraw revert
        adapter.setWithdrawReverts(true);

        uint256 before = usdc.balanceOf(savingsAccount);
        // withdrawMax returns what's available — mock returns balance
        vm.prank(savingsAccount);
        router.withdraw(500e6, savingsAccount, savingsAccount);
        uint256 after_ = usdc.balanceOf(savingsAccount);

        // Should have received 500e6 via withdrawMax
        assertEq(after_ - before, 500e6);
    }

    // ── harvest ───────────────────────────────────────────────────────────────

    function test_harvest_distributesFeeAndBuffer() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        adapter.setAPY(500); // 5%
        adapter.setHarvestYield(100e6); // 100 USDC gross yield

        vm.warp(block.timestamp + 5 minutes + 1); // past cooldown

        router.harvest();

        // fee = 10% of 100 = 10 USDC
        assertEq(usdc.balanceOf(treasury), 10e6);
        // buffer = 5% of 100 = 5 USDC
        assertEq(usdc.balanceOf(circleBuffer), 5e6);
        // net = 85 USDC stays in router (raises totalAssets)
        assertGt(router.totalAssets(), 0);
    }

    function test_harvest_emitsYieldHarvestedEvent() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        adapter.setAPY(500);
        adapter.setHarvestYield(100e6);

        vm.warp(block.timestamp + 5 minutes + 1);
        uint256 expectedTs = block.timestamp; // already warped

        vm.expectEmit(false, false, false, true);
        emit IYieldRouter.YieldHarvested(100e6, 10e6, 5e6, 85e6, expectedTs);
        router.harvest();
    }

    function test_harvest_idempotentOnZeroYield() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        adapter.setAPY(500);
        // No yield set

        vm.warp(block.timestamp + 5 minutes + 1);
        router.harvest(); // returns 0, no event

        assertEq(usdc.balanceOf(treasury), 0);
    }

    function test_harvest_enforcesCooldown() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        adapter.setHarvestYield(10e6);
        vm.warp(block.timestamp + 5 minutes + 1);
        router.harvest(); // first harvest ok

        // Second harvest before cooldown should revert
        adapter.setHarvestYield(5e6);
        vm.expectRevert(
            abi.encodeWithSelector(
                YieldRouter.HarvestCooldownActive.selector,
                block.timestamp + 5 minutes
            )
        );
        router.harvest();
    }

    function test_harvest_circuitBreakerOnApyDrop() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        adapter.setAPY(500); // 5%
        adapter.setHarvestYield(10e6);
        vm.warp(block.timestamp + 5 minutes + 1);
        router.harvest(); // records lastHarvestApyBps = 500

        // Advance time and drop APY by > 50%
        vm.warp(block.timestamp + 5 minutes + 1);
        adapter.setAPY(200); // dropped from 500 to 200 — > 50% drop

        // First harvest with drop: sets flag and returns (does NOT revert)
        router.harvest();
        assertTrue(router.circuitBreakerTripped());

        // Subsequent harvest reverts
        vm.warp(block.timestamp + 5 minutes + 1);
        vm.expectRevert(IYieldRouter.CircuitBreakerActive.selector);
        router.harvest();
    }

    // ── circuit breaker reset ─────────────────────────────────────────────────

    function test_resetCircuitBreaker_ownerOnly() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);
        _tripCircuitBreaker();
        assertTrue(router.circuitBreakerTripped());

        vm.prank(owner);
        router.resetCircuitBreaker();

        assertFalse(router.circuitBreakerTripped());
    }

    function test_resetCircuitBreaker_revertsIfNotOwner() public {
        _tripCircuitBreaker();

        vm.prank(makeAddr("rando"));
        vm.expectRevert();
        router.resetCircuitBreaker();
    }

    // ── fee governance ────────────────────────────────────────────────────────

    function test_setFeeRate_updatesAndEnforcesMax() public {
        vm.prank(owner);
        router.setFeeRate(1500); // 15%
        assertEq(router.feeRateBps(), 1500);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(YieldRouter.FeeTooHigh.selector, 2100, 2000));
        router.setFeeRate(2100);
    }

    function test_setBufferRate_updatesAndEnforcesMax() public {
        vm.prank(owner);
        router.setBufferRate(800); // 8%
        assertEq(router.bufferRateBps(), 800);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(YieldRouter.BufferTooHigh.selector, 1100, 1000));
        router.setBufferRate(1100);
    }

    function test_getFeeInfo_returnsCorrectValues() public {
        (uint256 fee, uint256 buffer, address treas) = router.getFeeInfo();
        assertEq(fee, 1000);
        assertEq(buffer, 500);
        assertEq(treas, treasury);
    }

    // ── getBlendedAPY / getCircuitBreakerStatus / getTotalAllocated ───────────

    function test_getBlendedAPY_delegatesToAdapter() public {
        adapter.setAPY(750);
        assertEq(router.getBlendedAPY(), 750);
    }

    function test_getCircuitBreakerStatus_reflectsState() public {
        assertFalse(router.getCircuitBreakerStatus());
        vm.prank(savingsAccount);
        router.allocate(1000e6);
        _tripCircuitBreaker();
        assertTrue(router.getCircuitBreakerStatus());
    }

    function test_getTotalAllocated_equalsAdapterBalance() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);
        assertEq(router.getTotalAllocated(), 1000e6);
    }

    // ── share price appreciation ───────────────────────────────────────────────

    function test_sharePriceRisesAfterHarvest() public {
        vm.prank(savingsAccount);
        router.allocate(1000e6);

        uint256 sharesBefore = router.balanceOf(savingsAccount);
        uint256 assetsBefore = router.convertToAssets(sharesBefore);

        adapter.setAPY(500);
        adapter.setHarvestYield(50e6); // 5% yield
        vm.warp(block.timestamp + 5 minutes + 1);
        router.harvest();

        uint256 assetsAfter = router.convertToAssets(sharesBefore);
        // Net yield = 50 - 5 (fee) - 2.5 (buffer) = 42.5 stays in pool
        assertGt(assetsAfter, assetsBefore);
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    function _tripCircuitBreaker() internal {
        adapter.setAPY(500);
        adapter.setHarvestYield(10e6);
        vm.warp(block.timestamp + 5 minutes + 1);
        router.harvest(); // records lastHarvestApyBps = 500

        vm.warp(block.timestamp + 5 minutes + 1);
        adapter.setAPY(100); // >50% drop
        // First call sets the flag and returns — does NOT revert
        router.harvest();
        assertTrue(router.circuitBreakerTripped());
    }
}
