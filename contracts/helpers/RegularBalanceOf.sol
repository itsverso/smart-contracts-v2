//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract RegularBalanceOf {
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {}
    function balanceOf(address account) public view virtual returns (uint256) {}
}