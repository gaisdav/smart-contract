// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; 

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityProvider is Ownable {
    INonfungiblePositionManager public positionManager;
    ISwapRouter public swapRouter;
    address public usdc;
    uint public feePercent;  // Процент комиссии

    // Структура для хранения позиции пользователя
    struct Position {
        uint tokenId;
        address tokenA;
        address tokenB;
    }

    mapping(address => Position) public userPositions; // Хранение информации о позициях для каждого пользователя

    constructor(
        address _positionManager,
        address _swapRouter,
        address _usdc,
        uint _feePercent
        ) Ownable(msg.sender) {
        positionManager = INonfungiblePositionManager(_positionManager);
        swapRouter = ISwapRouter(_swapRouter);
        usdc = _usdc;
        feePercent = _feePercent;
    }

    // external onlyOwner
    function setFeePercent(uint _feePercent) external onlyOwner  {
        feePercent = _feePercent;
    }
 
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountA,
        uint amountB,
        uint24 feeTier,
        int24 tickLower,
        int24 tickUpper
    ) external {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        IERC20(tokenA).approve(address(positionManager), amountA);
        IERC20(tokenB).approve(address(positionManager), amountB);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: tokenA,
            token1: tokenB,
            fee: feeTier,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amountA,
            amount1Desired: amountB,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 15
        });

        (uint tokenId,,,) = positionManager.mint(params);

        // Сохраняем позицию для пользователя с tokenId, tokenA и tokenB
        userPositions[msg.sender] = Position(tokenId, tokenA, tokenB);
    }

    function claimRewards() external {
        // Получаем информацию о позиции пользователя
        Position memory position = userPositions[msg.sender];
        require(position.tokenId != 0, "No position found for this user");

        // Параметры для сбора комиссий
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: position.tokenId,
            recipient: address(this),  // Собираем награды на контракт
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        // Выполняем сбор наград (комиссий)
        (uint amount0, uint amount1) = positionManager.collect(params);

        // Выполняем свап всех токенов в USDC
        uint usdcFromTokenA = 0;
        uint usdcFromTokenB = 0;

        if (amount0 > 0) {
            usdcFromTokenA = swapTokensForUSDC(amount0, position.tokenA);
        }
        if (amount1 > 0) {
            usdcFromTokenB = swapTokensForUSDC(amount1, position.tokenB);
        }

        // Рассчитываем общую сумму в USDC
        uint totalUSDC = usdcFromTokenA + usdcFromTokenB;

        // Рассчитываем комиссию
        uint feeAmount = (totalUSDC * feePercent) / 100;

        // Переводим комиссию владельцу контракта
        IERC20(usdc).transfer(owner(), feeAmount);

        // Отправляем оставшуюся часть USDC пользователю
        uint userAmount = totalUSDC - feeAmount;
        IERC20(usdc).transfer(msg.sender, userAmount);

        // Логируем событие
        emit RewardsClaimed(totalUSDC, feeAmount, userAmount);
    }

    function swapTokensForUSDC(uint amountIn, address fromToken) internal returns (uint amountOut) {
        // Одобряем токены для свапа
        IERC20(fromToken).approve(address(swapRouter), amountIn);

        // Параметры для обмена токенов
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: fromToken,
            tokenOut: usdc,
            fee: 3000,  // 0.3% стандартная комиссия для свапа
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Выполняем обмен
        amountOut = swapRouter.exactInputSingle(params);
    }

    event RewardsClaimed(uint totalUSDC, uint feeAmount, uint userAmount);
}
