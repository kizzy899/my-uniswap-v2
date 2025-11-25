// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IERC20.sol";
import "./UniswapV2ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IUniswapV2Callee.sol";

contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;           
    uint112 private reserve1;           
    uint32  private blockTimestampLast; 

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;

    uint public kLast;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        factory = msg.sender;
    }

    function getReserves() public view returns 
        (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) 
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "UniswapV2: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }
    function setTokens(address _token0, address _token1) external {
    require(msg.sender == factory, "FORBIDDEN");
    token0 = _token0;
    token1 = _token1;
}
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);

        uint _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0) * uint(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    uint denominator = (rootK * 5) + rootKLast;
                    uint liquidity = numerator / denominator;

                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);

        if (feeOn) kLast = uint(reserve0) * uint(reserve1);

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;

        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);

        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);

        if (feeOn) kLast = uint(reserve0) * uint(reserve1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data)
        external
        lock
    {
        require(amount0Out > 0 || amount1Out > 0, "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();

        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        uint balance0;
        uint balance1;

        {
            address _token0 = token0;
            address _token1 = token1;

            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");

            if (amount0Out > 0) IERC20(_token0).transfer(to, amount0Out);
            if (amount1Out > 0) IERC20(_token1).transfer(to, amount1Out);

            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        uint amount0In = balance0 > (_reserve0 - amount0Out)
            ? balance0 - (_reserve0 - amount0Out)
            : 0;

        uint amount1In = balance1 > (_reserve1 - amount1Out)
            ? balance1 - (_reserve1 - amount1Out)
            : 0;

        require(amount0In > 0 || amount1In > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");

        {
            uint balance0Adj = (balance0 * 1000) - (amount0In * 3);
            uint balance1Adj = (balance1 * 1000) - (amount1In * 3);

            require(
                balance0Adj * balance1Adj >= uint(_reserve0) * uint(_reserve1) * (1000**2),
                "UniswapV2: K"
            );
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function sync() external lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
}