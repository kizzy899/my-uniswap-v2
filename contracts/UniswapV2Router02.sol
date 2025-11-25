// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2ERC20.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./UniswapV2Library.sol";
import "./utils/TransferHelper.sol";

contract UniswapV2Router02 is IUniswapV2Router02 {
    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    // ===========================================================================================
    // Internal addLiquidity calculation
    // REMOVED "view" keyword here because createPair modifies state
    // ===========================================================================================
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint amountA, uint amountB) { 

        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }

        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            return (amountADesired, amountBDesired);
        }

        uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);

        if (amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
            return (amountADesired, amountBOptimal);
        }

        uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);

        require(amountAOptimal >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");

        return (amountAOptimal, amountBDesired);
    }

    // ===========================================================================================
    // Add Liquidity
    // ===========================================================================================
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override ensure(deadline)
      returns (uint amountA, uint amountB, uint liquidity)
    {
        (amountA, amountB) =
            _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);

        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    // ===========================================================================================
    // Add Liquidity ETH
    // ===========================================================================================
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable override ensure(deadline)
      returns (uint amountToken, uint amountETH, uint liquidity)
    {
        (amountToken, amountETH) = _addLiquidity(
            token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin
        );

        address pair = UniswapV2Library.pairFor(factory, token, WETH);

        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);

        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));

        liquidity = IUniswapV2Pair(pair).mint(to);

        if (msg.value > amountETH) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        }
    }

    // ===========================================================================================
    // Remove Liquidity
    // ===========================================================================================
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public override ensure(deadline)
      returns (uint amountA, uint amountB)
    {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        TransferHelper.safeTransferFrom(pair, msg.sender, pair, liquidity);

        (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(to);

        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);

        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);

        require(amountA >= amountAMin, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    // ===========================================================================================
    // Remove Liquidity ETH
    // ===========================================================================================
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public override ensure(deadline)
      returns (uint amountToken, uint amountETH)
    {
        (amountToken, amountETH) =
            removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);

        TransferHelper.safeTransfer(token, to, amountToken);

        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // ===========================================================================================
    // Remove Liquidity with Permit
    // ===========================================================================================
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amountA, uint amountB)
    {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        uint value = approveMax ? type(uint).max : liquidity;

        IUniswapV2ERC20(pair).permit(
            msg.sender, address(this), value, deadline, v, r, s
        );

        (amountA, amountB) =
            removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    // ===========================================================================================
    // Swap Helpers
    // ===========================================================================================
    function _swap(uint[] memory amounts, address[] memory path, address _to) private {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i+1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i+1];

            (uint amount0Out, uint amount1Out) =
                input == token0
                    ? (uint(0), amountOut)
                    : (amountOut, uint(0));

            address to =
                i < path.length - 2
                    ? UniswapV2Library.pairFor(factory, output, path[i+2])
                    : _to;

            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    // Payment into first pool
    function _safeTransferToPair(address token, address from, address to, uint amount) private {
        TransferHelper.safeTransferFrom(token, from, to, amount);
    }

    // ===========================================================================================
    // SWAP Exact Tokens for Tokens
    // ===========================================================================================
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline)
      returns (uint[] memory amounts)
    {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

        require(amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);

        _safeTransferToPair(path[0], msg.sender, pair, amounts[0]);

        _swap(amounts, path, to);
    }

    // ===========================================================================================
    // SWAP Tokens for Exact Tokens
    // ===========================================================================================
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline)
      returns (uint[] memory amounts)
    {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);

        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);

        _safeTransferToPair(path[0], msg.sender, pair, amounts[0]);

        _swap(amounts, path, to);
    }

    // ===========================================================================================
    // SWAP Exact ETH For Tokens
    // ===========================================================================================
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override ensure(deadline)
      returns (uint[] memory amounts)
    {
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);

        require(amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(
            UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        ));

        _swap(amounts, path, to);
    }

    // ===========================================================================================
    // SWAP Exact Tokens For ETH
    // ===========================================================================================
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline)
      returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

        require(amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);

        _safeTransferToPair(path[0], msg.sender, pair, amounts[0]);

        _swap(amounts, path, address(this));

        uint amountETH = amounts[amounts.length - 1];

        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // ===========================================================================================
    // SWAP Supporting Fee On Transfer Tokens（FOT）
    // ===========================================================================================
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) private {

        for (uint i; i < path.length - 1; i++) {
            (address input, address output) =
                (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);

            IUniswapV2Pair pair =
                IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));

            (uint reserve0, uint reserve1,) = pair.getReserves();

            (uint reserveInput, uint reserveOutput) =
                input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);

            uint balanceInput =
                IERC20(input).balanceOf(address(pair));
            uint amountInput = balanceInput - reserveInput;

            uint amountOutput =
                UniswapV2Library.getAmountOut(
                    amountInput, reserveInput, reserveOutput
                );

            (uint amount0Out, uint amount1Out) =
                input == token0
                    ? (uint(0), amountOutput)
                    : (amountOutput, uint(0));

            address to =
                i < path.length - 2
                    ? UniswapV2Library.pairFor(factory, output, path[i+2])
                    : _to;

            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    // ===========================================================================================
    // Supporting fee on transfer: ExactTokensForTokens
    // ===========================================================================================
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline)
    {
        address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);

        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amountIn);

        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        _swapSupportingFeeOnTransferTokens(path, to);

        uint amountOut =
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore;

        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    // ===========================================================================================
    // Supporting fee on transfer: ExactETHForTokens
    // ===========================================================================================
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        payable
        override
        ensure(deadline)
    {
        require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore;
        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    // ===========================================================================================
    // Supporting fee on transfer: ExactTokensForETH
    // ===========================================================================================
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // ===========================================================================================
    // QUERY functions
    // ===========================================================================================
    function quote(uint amountA, uint reserveA, uint reserveB)
        external pure override returns (uint amountB)
    {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountsOut(uint amountIn, address[] calldata path)
        external view override returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] calldata path)
        external view override returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }
}