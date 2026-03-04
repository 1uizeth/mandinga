// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {SavingsAccount} from "../../src/core/SavingsAccount.sol";
import {ISavingsAccount} from "../../src/interfaces/ISavingsAccount.sol";
import {IYieldRouter} from "../../src/interfaces/IYieldRouter.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Minimal mock USDC
// ─────────────────────────────────────────────────────────────────────────────

contract InvMockUSDC is IERC20 {
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

// ─────────────────────────────────────────────────────────────────────────────
// Minimal mock YieldRouter
// ─────────────────────────────────────────────────────────────────────────────

contract InvMockYieldRouter is IYieldRouter {
    InvMockUSDC public usdc;
    uint256 public totalAllocated;

    constructor(address _usdc) {
        usdc = InvMockUSDC(_usdc);
    }

    function allocate(uint256 amount) external override {
        usdc.transferFrom(msg.sender, address(this), amount);
        totalAllocated += amount;
    }

    function harvest() external override {}

    function getBlendedAPY() external pure override returns (uint256) {
        return 500;
    }

    function getCircuitBreakerStatus() external pure override returns (bool) {
        return false;
    }

    function getTotalAllocated() external view override returns (uint256) {
        return totalAllocated;
    }

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

    function maxWithdraw(address) external view override returns (uint256) {
        return totalAllocated;
    }

    function maxRedeem(address) external view override returns (uint256) {
        return totalAllocated;
    }

    function previewDeposit(uint256 a) external pure override returns (uint256) { return a; }
    function previewMint(uint256 s) external pure override returns (uint256) { return s; }
    function previewWithdraw(uint256 a) external pure override returns (uint256) { return a; }
    function previewRedeem(uint256 s) external pure override returns (uint256) { return s; }

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

    function name() external pure override returns (string memory) { return "MockRouter"; }
    function symbol() external pure override returns (string memory) { return "MR"; }
    function decimals() external pure override returns (uint8) { return 6; }
    function totalSupply() external pure override returns (uint256) { return 0; }
    function balanceOf(address) external pure override returns (uint256) { return 0; }
    function transfer(address, uint256) external pure override returns (bool) { return true; }
    function transferFrom(address, address, uint256) external pure override returns (bool) { return true; }
    function allowance(address, address) external pure override returns (uint256) { return 0; }
    function approve(address, uint256) external pure override returns (bool) { return true; }
}

// ─────────────────────────────────────────────────────────────────────────────
// Handler — drives random state transitions for the fuzzer
// ─────────────────────────────────────────────────────────────────────────────

/// @dev Inherits Test so it has access to `vm` cheatcodes.
contract SavingsAccountHandler is Test {
    // Well-known Foundry cheatcodes address
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    SavingsAccount public sa;
    InvMockUSDC public usdc;
    address public circleContract;

    address[] public actors;

    /// @dev Track all shieldedIds that have been touched so invariants can be checked.
    bytes32[] public touchedIds;
    mapping(bytes32 => bool) private _tracked;

    constructor(address _sa, address _usdc, address _circle, address[] memory _actors) {
        sa = SavingsAccount(_sa);
        usdc = InvMockUSDC(_usdc);
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
    InvMockUSDC internal usdc;
    InvMockYieldRouter internal router;
    SavingsAccount internal sa;
    SavingsAccountHandler internal handler;

    address internal emergencyModuleAddr = makeAddr("emergencyModule");
    address internal savingsCircleAddr = makeAddr("savingsCircle");

    address[] internal actors;

    function setUp() public {
        usdc = new InvMockUSDC();
        router = new InvMockYieldRouter(address(usdc));
        sa = new SavingsAccount(
            IYieldRouter(address(router)),
            emergencyModuleAddr,
            savingsCircleAddr,
            address(usdc)
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
        // Also check all known actors in case handler didn't touch them yet
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
            // This call panics on underflow — catching that here is the assertion
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
