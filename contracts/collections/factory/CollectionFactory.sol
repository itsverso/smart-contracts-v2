//SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 < 0.9.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../Collection.sol";
import "./CollectionBeacon.sol";
import "../CollectionRegistry.sol";

/**
 * @title  Collection Factory Smart Contract
 * @author Hugo Sanchez
 * @notice Simple smart contracts to create new collections it basically:
 *         1- Calls CollectionBeacon.sol to instantiate a new proxy.
 *         2- Calls ProfileRegstry.sol to add the new collection to the user profile.
 *         3- Returns new collection address 
 */

contract CollectionFactory is Ownable, Pausable {

    // Collection registry 
    address _collectionRegistryAddress;

    // Beacon proxy
    CollectionBeacon immutable collectionBeacon;

    // Simple event
    event CollectionCreated(address newCollectionAddress, address creator, string metadataURI);


    ////////////////////////////
    // Constructor
    ////////////////////////////

    constructor(
        address _initialImplementation, 
        address _owner
    ) 
        Ownable(_owner)
        Pausable()
    {
        collectionBeacon = new CollectionBeacon(_initialImplementation);
    }
    

    ////////////////////////////
    // Entrypoint: create
    ////////////////////////////
    function createCollection(
        string calldata _collectionName,
        uint _readType,
        uint _writeType,
        address _collectionPermissions,
        uint _minimumBalance,
        string calldata _collectionMetadataURI
        // address _marketAddress,
        // uint _tokenPrice,
        // bool _isBonded
    ) 
        external
        whenNotPaused() 
        returns (address) 
    {
        
        // 1. Instantiate collection
        BeaconProxy collection = new BeaconProxy(address(collectionBeacon), 
            abi.encodeWithSelector(Collection(payable(address(0))).initialize.selector,
            _collectionName,
            msg.sender,
            _readType,
            _writeType,
            _collectionPermissions,
            _minimumBalance
        ));

        // 2. Register / mint collection
        CollectionRegistry registry = CollectionRegistry(_collectionRegistryAddress);
        registry.registerCollection(
            msg.sender, 
            address(collection), 
            _collectionMetadataURI,
            _collectionPermissions
        );
    
        
        // 3. Emit event 
        emit CollectionCreated(address(collection), msg.sender, _collectionMetadataURI);
        return address(collection);
    }

    ////////////////////////////
    // Basics
    ////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }
 
    function unpause() external onlyOwner {
        _unpause();
    }

    function getBeacon() public view returns (address) {
        return address(collectionBeacon);
    }

    function getImplementation() public view returns (address) {
        return collectionBeacon.implementation();
    }

    function setCollectionRegistryAddress(address _newAddress) 
        public 
        onlyOwner() 
        whenNotPaused()
    {
        _collectionRegistryAddress = _newAddress;
    }

}