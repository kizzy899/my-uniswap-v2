// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UniswapV2Library.sol"; // 请根据你的实际路径修改引用

contract MockUniswapV2Library {
    // 将 internal 函数包装为 external 供测试调用
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1) {
        return UniswapV2Library.sortTokens(tokenA, tokenB);
    }

    // 如果还需要测试 pairFor 等其他函数，也可以在这里添加包装
}