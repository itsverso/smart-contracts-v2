//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title  New Profile Registry Smart Contract
 * @author Hugo Sanchez 
 * @notice This is the main entry point to verso. Every profile is an ERC721
 *         which has the following properties:
 *              1- a handle (unique)
 *              2- a metadata url (updatable)
 *              3- a subscribe module (address, updatable)
 *          
 *         This is a much simpler version where we have removed the collections array.
 */ 

contract ProfileRegistry is 

    Initializable, 
    ERC721URIStorageUpgradeable, 
    OwnableUpgradeable, 
    UUPSUpgradeable,
    PausableUpgradeable
{
    
    ////////////////////////////////
    // Constants & Mappings 
    ///////////////////////////////
    uint private _tokenIds;
    address public followRegistryAddress;

    // Mapping address to profile ID
    mapping(address => uint256) public addressToProfileID;
    // Mapping handle to profile ID.
    mapping(bytes32 => uint256) handleOwnershipById;
    // Mapping ID to profile details.
    mapping(uint256 => Profile) idToProfileDetails;

    // Profiles struct
    struct Profile {
        string handle;
        string metadataURI;
        address subscribeModule;
    }

    ////////////////////////////////
    // Constants & Mappings 
    ///////////////////////////////
    // Event: New profile created
    event NewProfileCreated(
        address account, 
        string handle, 
        string metadataURI
    );

    ////////////////////////////////
    // Initialize 
    ///////////////////////////////
    function initialize(
        address _owner
    ) 
        public initializer {
            _tokenIds++;
            // Initiate ownable 
            __Ownable_init(_owner);
            transferOwnership(_owner);
            // Initiate UUPS
            __UUPSUpgradeable_init();
            // Initiate pausable
            __Pausable_init_unchained();
            // Initiate ERC721 
            __ERC721_init("Verso Profile Registry", "VPR");
            __ERC721URIStorage_init();
            
    }


    ////////////////////////////////
    // Modifiers 
    ///////////////////////////////
    // Check token exists
    modifier exists(uint tokenId) {
        require(
            tokenId < _tokenIds,
            "Token doesn't exists"
        );
        _;
    }

    // Only profile owner can change
    modifier onlyProfileOwner(uint _profileId) {
        require(
            addressToProfileID[msg.sender] == _profileId,
            "Can't change someone else's metadata"
        );
        _;
    }


    ////////////////////////////////
    // Basics 
    ///////////////////////////////

    // Pausing
    function pause() external onlyOwner {
        _pause();
    }
 
    // Unpausing
    function unpause() external onlyOwner {
        _unpause();
    }

    // Authorize upgrade
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // Returns current tokenID
    function getTokenId() public view returns (uint) {
        return _tokenIds;
    }

    // Returns ProfileStruct for a given tokenID.
    function getProfileByID(uint256 _id) public view returns (Profile memory) {
        return idToProfileDetails[_id];
    }

     // Returns token ID from handle.
    function getIdFromHandle(string calldata _handle) public view returns (uint256) {
        bytes32 handleHash = keccak256(bytes(_toLower(_handle)));
        return handleOwnershipById[handleHash];
    }


    ////////////////////////////////
    // Core  
    ///////////////////////////////

    /// @param recipient: address of profile owner
    /// @param _handle: handle chosen
    /// @param _metadataURI: profile metadata uri
    /// This is the main function:
    /// given a handle and URL, mints a new profile as NFT. 
    function registerProfile(
        address recipient, 
        string calldata _handle,
        string calldata _metadataURI
    )
        public
        whenNotPaused() 
    {
        // Create hash of handle.
        bytes32 handleHash = keccak256(bytes(_toLower(_handle)));
        // Only one profile per address. 
        require(
            addressToProfileID[recipient] == 0,
            "Already has profile"
        );
        // Make sure not two handles are equal.
        require(handleOwnershipById[handleHash] == 0, "Handle already taken");
        // Get current count.
        uint256 newRecordId = _tokenIds++;
        // Map address to tokenID.
        addressToProfileID[recipient] = newRecordId;
        // Map handle to tokenID.
        handleOwnershipById[handleHash] = newRecordId;
        // Map tokenID to profile struct.
        idToProfileDetails[newRecordId].handle = _handle;
        idToProfileDetails[newRecordId].metadataURI = _metadataURI;
        // Mint new token/profile.
        _safeMint(recipient, newRecordId);
        // Set profile details (URL).
        _setTokenURI(newRecordId, _metadataURI);
        // Emit event 
        emit NewProfileCreated(recipient, _handle, _metadataURI);
    }

    /// @param _profileId: profile token ID
    /// @param _metadataURI: new metadata URL. 
    /// Change profile metadata URL (name, description, image) but never handle.
    /// Only users and only for the profile they own.
    function updateProfileMetadata(
        uint256 _profileId,
        string calldata _metadataURI
    ) 
        public
        whenNotPaused()
        exists(_profileId)
        onlyProfileOwner(_profileId)
    {
        idToProfileDetails[_profileId].metadataURI = _metadataURI;
    }

    /// @param _profileId: profile token ID
    /// @param _subscribeModule: subscribe module address
    /// Set follow module for a given user.
    /// Only users and only for the profile they own.
    function updateSubscribeModule(
        uint256 _profileId,
        address _subscribeModule
    ) 
        public
        whenNotPaused()
        exists(_profileId) 
        onlyProfileOwner(_profileId)
    {
        idToProfileDetails[_profileId].subscribeModule = _subscribeModule;
    }


    // Helper function.
    // Turns any string to lower case.
    // Borrowed from: https://gist.github.com/ottodevs/c43d0a8b4b891ac2da675f825b1d1dbf
    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

}