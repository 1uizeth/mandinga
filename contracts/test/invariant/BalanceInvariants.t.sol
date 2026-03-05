// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Vm} from "forge-std/Vm.sol";

import {SavingsAccount} from "../../src/core/SavingsAccount.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockYieldRouter} from "../mocks/MockYieldRouter.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Handler — drives random state transitions for the fuzzer
// ─────────────────────────────────────────────────────────────────────────────

/// @dev Inherits Test so it has access to `vm` cheatcodes.
contract SavingsAccountHandler is Test {
    SavingsAccount public sa;
    MockUSDC public usdc;
    address public circleContract;

    address[] public actors;

    /// @dev Track all shieldedIds that have been touched so invariants can be checked.
    bytes32[] public touchedIds;
    mapping(bytes32 => bool) private _tracked;

    constructor(address _sa, address _usdc, address _circle, address[] memory _actors) {
        sa = SavingsAccount(_sa);
        usdc = MockUSDC(_usdc);
        circleContract = _circle;
        actors = _actors;
    }

    // ── Internal helpers ──

    function _pickActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _track(bytes32 id) internal {
        if (!_tracked[id]) {
            touchedIds.push(id);
            _tracked[id] = true;
        }
    }

    // ── Actions ──

    function deposit(uint256 actorSeed, uint256 amount) external {
        amount = bound(amount, 1e6, 10_000e6);
        address actor = _pickActor(actorSeed);
        bytes32 id = sa.computeShieldedId(actor);
        _track(id);

        usdc.mint(actor, amount);

        vm.startPrank(actor);
        usdc.approve(address(sa), amount);
        sa.deposit(amount);
        vm.stopPrank();
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = _pickActor(actorSeed);
        bytes32 id = sa.computeShieldedId(actor);

        ISavingsAccount.Position memory pos = sa.getPosition(id);
        uint256 maxW = pos.balance - pos.circleObligation;
        if (maxW == 0) return;

        amount = bound(amount, 1, maxW);

        vm.prank(actor);
        sa.withdraw(amount);
    }

    function setObligation(uint256 actorSeed, uint256 amount) external {
        address actor = _pickActor(actorSeed);
        bytes32 id = sa.computeShieldedId(actor);

        ISavingsAccount.Position memory pos = sa.getPosition(id);
        if (pos.balance == 0) return;

        amount = bound(amount, 0, pos.balance);

        vm.prank(circleContract);
        sa.setCircleObligation(id, amount);
    }

    function releaseObligation(uint256 actorSeed) external {
        address actor = _pickActor(actorSeed);
        bytes32 id = sa.computeShieldedId(actor);

        vm.prank(circleContract);
        sa.setCircleObligation(id, 0);
    }

    function getTouchedIds() external view returns (bytes32[] memory) {
        return touchedIds;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invariant test suite
// ─────────────────────────────────────────────────────────────────────────────

contract BalanceInvariantsTest is StdInvariant, Test {
    MockUSDC internal usdc;
    MockYieldRouter internal router;
    SavingsAccount internal sa;
    SavingsAccountHandler internal handler;

    address internal emergencyModuleAddr = makeAddr("emergencyModule");
    address internal savingsCircleAddr = makeAddr("savingsCircle");

    address[] internal actors;

    function setUp() public {
        usdc = new MockUSDC();
        router = new MockYieldRouter(address(usdc));
        sa = new SavingsAccount(
            IYieldRouter(address(router)),
            emergencyModuleAddr,
            savingsCircleAddr,
            address(usdc),
            address(0)      // safetyNetPool — not used in invariant tests
        );

        // Fund router with ample USDC to cover all withdrawals
        usdc.mint(address(router), 1_000_000e6);

        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));

        handler = new SavingsAccountHandler(address(sa), address(usdc), savingsCircleAddr, actors);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = SavingsAccountHandler.deposit.selector;
        selectors[1] = SavingsAccountHandler.withdraw.selector;
        selectors[2] = SavingsAccountHandler.setObligation.selector;
        selectors[3] = SavingsAccountHandler.releaseObligation.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // ──────────────────────────────────────────────
    // Invariants
    // ──────────────────────────────────────────────

    /// @notice Core invariant: for every position, balance >= circleObligation.
    function invariant_balanceAlwaysGteObligation() public view {
        bytes32[] memory ids = handler.getTouchedIds();
        for (uint256 i = 0; i < ids.length; i++) {
            ISavingsAccount.Position memory pos = sa.getPosition(ids[i]);
            assertGe(
                pos.balance,
                pos.circleObligation,
                "invariant_balanceAlwaysGteObligation violated"
            );
        }
        for (uint256 i = 0; i < actors.length; i++) {
            bytes32 id = sa.computeShieldedId(actors[i]);
            ISavingsAccount.Position memory pos = sa.getPosition(id);
            assertGe(pos.balance, pos.circleObligation, "invariant_balanceAlwaysGteObligation violated (actors)");
        }
    }

    /// @notice Withdrawable balance never underflows (would panic if balance < obligation).
    function invariant_withdrawableNeverUnderflows() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            bytes32 id = sa.computeShieldedId(actors[i]);
            sa.getWithdrawableBalance(id);
        }
    }

    /// @notice Exited positions have zero balance and zero obligation.
    function invariant_exitedPositionIsFullyCleared() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            bytes32 id = sa.computeShieldedId(actors[i]);
            ISavingsAccount.Position memory pos = sa.getPosition(id);
            if (pos.emergencyExit) {
                assertEq(pos.balance, 0, "exited position balance must be zero");
                assertEq(pos.circleObligation, 0, "exited position obligation must be zero");
            }
        }
    }
}
