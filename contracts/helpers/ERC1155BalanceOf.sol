//SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 < 0.9.0;

contract ERC1155BalanceOf {
    function balanceOf(address account, uint tokenId) public view virtual returns (uint256) {}
}
