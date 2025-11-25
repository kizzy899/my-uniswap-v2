// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Math {
    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

    // Uniswap V2 uses Babylonian method for sqrt
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}