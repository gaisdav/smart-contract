// contracts/mocks/MockPositionManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockPositionManager {
    function mint(
        address,
        address,
        uint24,
        int24,
        int24,
        uint256,
        uint256,
        uint256,
        uint256,
        address,
        uint256
    )
        external
        pure
        returns (
            uint256 tokenId,
            uint256 amount0,
            uint256 amount1,
            uint128 liquidity
        )
    {
        // Возвращаем тестовые значения
        return (1, 1000, 2000, 100);
    }
}
