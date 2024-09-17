// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockSwapRouter {
    address public tokenIn;
    address public tokenOut;
    uint public amountIn;
    uint public amountOut;

    // Функция для мок-свапа токенов
    function exactInputSingle(
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        uint _amountOut
    ) external returns (uint) {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        amountIn = _amountIn;
        amountOut = _amountOut;
        return _amountOut;
    }
}
