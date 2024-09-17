const {expect} = require('chai')
const {ethers} = require('hardhat')

describe('LiquidityProvider', function () {
    let liquidityProvider
    let owner
    let addr1
    let addr2
    let addr3
    let tokenA
    let tokenB
    let positionManager
    let swapRouter
    let usdc

    beforeEach(async function () {
        // Деплой контракта
        [owner, addr1, addr2] = await ethers.getSigners()

        // Разворачиваем тестовые токены A и B (ERC-20)
        const Token = await ethers.getContractFactory('ERC20Mock')
        tokenA = await Token.deploy('Token A', 'TKA', 1000000)
        tokenB = await Token.deploy('Token B', 'TKB', 1000000)

        const MockSwapRouter = await ethers.getContractFactory('MockSwapRouter')
        swapRouter = await MockSwapRouter.deploy()

        // Разворачиваем мок INonfungiblePositionManager
        const MockPositionManager = await ethers.getContractFactory(
            'MockPositionManager'
        )
        positionManager = await MockPositionManager.deploy()
        await positionManager.deployed()

        usdc = await Token.deploy('USD Coin', 'USDC', 1000000)

        const LiquidityProvider = await ethers.getContractFactory(
            'LiquidityProvider'
        )
        liquidityProvider = await LiquidityProvider.deploy(
            positionManager.address,
            swapRouter.address,
            usdc.address,
            5
        )
        await liquidityProvider.deployed()
    })

    it('Should allow user to add liquidity', async function () {
        const amountA = 1000
        const amountB = 2000

        // Токены на баланс addr1
        await tokenA.transfer(addr1.address, amountA)
        await tokenB.transfer(addr1.address, amountB)

        // Одобряем контракт на использование токенов addr1
        await tokenA.connect(addr1).approve(liquidityProvider.address, amountA)
        await tokenB.connect(addr1).approve(liquidityProvider.address, amountB)

        // Вызов addLiquidity от addr1
        await liquidityProvider.connect(addr1).addLiquidity(
            tokenA.address,
            tokenB.address,
            amountA,
            amountB,
            3000, // feeTier
            -60000, // tickLower
            60000 // tickUpper
        )

        // Проверяем, что баланс контракта обновился
        expect(await tokenA.balanceOf(liquidityProvider.address).toString()).to.equal(
            amountA.toString()
        )
        expect(await tokenB.balanceOf(liquidityProvider.address).toString()).to.equal(
            amountB.toString()
        )

        // Проверяем, что позиция для addr1 сохранена
        const position = await liquidityProvider.userPositions(addr1.address)
        expect(position.tokenId.toString()).to.not.equal('0')
        expect(position.tokenA).to.equal(tokenA.address)
        expect(position.tokenB).to.equal(tokenB.address)
    })

    it('Should revert if insufficient token balance', async function () {
        const amountA = 1000
        const amountB = 2000

        // Одобряем контракт на использование токенов addr1, но не переводим их
        await tokenA.connect(addr1).approve(liquidityProvider.address, amountA)
        await tokenB.connect(addr1).approve(liquidityProvider.address, amountB)

        // Вызов addLiquidity должен завершиться ошибкой, так как баланс addr1 недостаточен
        await expect(
            liquidityProvider.connect(addr1).addLiquidity(
                tokenA.address,
                tokenB.address,
                amountA,
                amountB,
                3000, // feeTier
                -60000, // tickLower
                60000 // tickUpper
            )
        ).to.be.revertedWith('ERC20: transfer amount exceeds balance')
    })

    it('Should allow the owner to set fee percent', async function () {
        // Проверяем начальное значение комиссии
        expect(await liquidityProvider.feePercent()).to.equal(5)

        // Устанавливаем новую комиссию
        await liquidityProvider.setFeePercent(10)

        // Проверяем, что комиссия обновлена
        expect(await liquidityProvider.feePercent()).to.equal(10)
    })

    it('Should revert when non-owner tries to set fee percent', async function () {
        // Пытаемся изменить комиссию от имени addr1 (не владелец)
        await expect(liquidityProvider.connect(addr1).setFeePercent(10)).to.be
            .reverted
    })
})
