//SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 < 0.9.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  Collection Beacon Smart Contract
 * @author Hugo Sanchez
 * @notice Simple smart contracts to handle updates to the Collection.sol smart contract. 
 */

contract CollectionBeacon is Ownable {

    UpgradeableBeacon immutable beacon;

    address public implementation;

    constructor(address _imp) Ownable(msg.sender) {
        beacon = new UpgradeableBeacon(_imp, msg.sender);
        implementation = _imp;
        transferOwnership(msg.sender);
    }

    function update(address _newImp) public onlyOwner {
        beacon.upgradeTo(_newImp);
        implementation = _newImp;
    }
}