// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
