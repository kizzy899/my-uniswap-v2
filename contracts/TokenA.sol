// contracts/test/TokenA.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenA is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // 添加一个公开的 mint 函数用于测试发币
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}