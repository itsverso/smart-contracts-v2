// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


library Params {

    struct CollectionInitParams {
        string _collectionName;
        string _collectionMetadataURI;
        uint8 _readType;
        uint8 _writeType;
        address _collectionPermissions;
        uint _minimumBalance;
        address _marketAddress;
        uint _supplyLimit; 
        uint _tokenPrice;
        bool _isBonded;
    }
}