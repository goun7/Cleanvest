// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IUniswapV3Router - Uniswap V3 SwapRouter Arayuzu
/// @notice Artik hacmi Uniswap v3'e yonlendirmek icin kullanilir.
/// @dev Uniswap TWAP ORACLE olarak KULLANILMAZ (dairesel fiyat) - bu
///      yalnizca likidite cikis kapisidir.
interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}
