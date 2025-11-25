// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";

library UniswapV2Library {
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
    }

    function pairFor(address factory, address tokenA, address tokenB)
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac427619fd2de8455d9c8daea02d57f075444ef32272acab56543e4d6e14" 
                        )
                    )
                )
            )
        );
    }

    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint reserveA, uint reserveB)
    {
        (address token0,) = sortTokens(tokenA, tokenB);

        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "UniswapV2: PAIR_NOT_EXISTS");

        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();

        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function quote(uint amountA, uint reserveA, uint reserveB)
        internal
        pure
        returns (uint amountB)
    {
        require(amountA > 0, "UniswapV2: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        internal
        pure
        returns (uint amountOut)
    {
        require(amountIn > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;

        amountOut = numerator / denominator;
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        internal
        pure
        returns (uint amountIn)
    {
        require(amountOut > 0, "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;

        amountIn = (numerator / denominator) + 1;
    }

    function getAmountsOut(address factory, uint amountIn, address[] memory path)
        internal
        view
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, "UniswapV2: INVALID_PATH");

        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i = 1; i < path.length; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i] = getAmountOut(amounts[i - 1], reserveIn, reserveOut);
        }
    }

    function getAmountsIn(address factory, uint amountOut, address[] memory path)
        internal
        view
        returns (uint[] memory amounts)
    {
        require(path.length >= 2, "UniswapV2: INVALID_PATH");

        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}