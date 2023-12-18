// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../MarketMaster.sol";
import "./Collection.sol";


/**
 * @title  Collection Registry Smart Contract
 * @author Hugo Sanchez 
 * @notice The collection registry allows to mint/buy/sell collections as NFTs (!)
 */ 



contract CollectionRegistry is 

    OwnableUpgradeable, 
    ERC1155Upgradeable, 
    UUPSUpgradeable, 
    PausableUpgradeable 

{
  
    // Counter
    uint private _tokenIds;
    // Factory 
    address private _collectionFactoryAddress;
    // default role
    bytes32 internal constant DEFAULT_MODERATORS_ROLE = keccak256("MODERATORS");

    
    ////////////////////////////
    // MAPPINGS section.
    //////////////////////////// 

    // Mapping collection smart contract address to tokenId
    mapping(address => uint256) public addressToTokenID;
    // Mapping token ID to collection smart contract address
    mapping(uint256 => address) public collectionAddresses;
    // Mapping token ID to collection smart contract address
    mapping(uint256 => string) private _uris;

    // TokenID => Supply
    mapping(uint256 => uint256) public tokenSupply;
    // TokenID => Permissions contract address 
    mapping(uint256 => address) public tokenPermissions;
    // TokenID => Market address
    mapping(uint256 => address) public marketAddresses;
    // TokenID => Creator
   // mapping(uint256 => address) public creator;  

    
    ////////////////////////////
    // EVENTS section.
    ////////////////////////////

    // Event: New item created
    event NewVersoCreated(address account, uint id, string metadataURI);
    // Event: New item collected
    event NewVersoCollected(address account, uint id, address contractAddress);
    // Event: Collection added
    event VersoDeleted(address moderator, address collection, uint tokenId);


    ////////////////////////////
    // MODIFIERS section.
    ////////////////////////////

    // Moderators
    modifier onlyFactoryOrOwner() {
        require(
            msg.sender == _collectionFactoryAddress || msg.sender == owner(),
            "only factory or owner allowed"
        );
        _;
    }


    ////////////////////////////////
    // Initialize 
    ///////////////////////////////
    function initialize(
        address _owner,
        address _factoryAddress
        ) public initializer {
            __Ownable_init(_owner);
            // Instantiate receiver
            __ERC1155_init("");
            // Initiate pausable
            __Pausable_init_unchained();
            // Set factory
            _collectionFactoryAddress = _factoryAddress;

    }


    ////////////////////////////////
    // Basic functions get/set
    ///////////////////////////////

    // Pausing
    function pause() external onlyOwner {
        _pause();
    }
 
    // Unpausing
    function unpause() external onlyOwner {
        _unpause();
    }

    // Smart contract name. 
    function name() public pure returns (string memory) {
        return "Verso Collections Registry";
    }

    // Smart contract symbol
    function symbol() public pure returns (string memory) {
        return "VCR";
    }

    function _setTokenUri(uint tokenId, string memory _uri) private {
        _uris[tokenId] = _uri;
    }

    // Get token URI
    function uri(uint tokenID) override public view returns (string memory) {
        return _uris[tokenID];
    }

    function setFactoryAddress(address _newFactoryAddress) public onlyOwner() {
        _collectionFactoryAddress = _newFactoryAddress;
    }

    // Sets the token metadata
    function _setTokenMetadata(
        uint256 tokenId,
        string memory url
    ) internal virtual returns (string memory) {
        require(bytes(_uris[tokenId]).length <= 20, "URI already set");
        _uris[tokenId] = url;
        return _uris[tokenId];
    }


    /////////////////////////////////
    // Core functionality
    ///////////////////////////////

    /// @param _creator: collection creator and first minter
    /// @param _collectionAddress: collection smart contract address
    /// @param _collectionMetadataUri: collection metadata

    function registerCollection(
        address _creator,
        address _collectionAddress,
        string calldata _collectionMetadataUri,
        address _permissions
    )
        public 
        whenNotPaused()
        onlyFactoryOrOwner()
    {   
        // 1. Get new Id.
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        // 2. Set mappings 
             
        tokenPermissions[newTokenId] = _permissions;
        collectionAddresses[newTokenId] = _collectionAddress;
        addressToTokenID[_collectionAddress] = newTokenId;
        // 3. Mint and set uri 
        _mint(_creator, newTokenId, 1, "");
        _setTokenUri(newTokenId, _collectionMetadataUri);
        _setTokenMetadata(newTokenId, _collectionMetadataUri);
        tokenSupply[newTokenId] = tokenSupply[newTokenId] + 1;

    }


    /// Allows moderators to update collection metadata uri.
    /// @param collectionAddress: the smart contract address for the collection.
    /// @param collectionMetadataUri: the new metadata uri.

    function updateCollectionMetadata(
        address collectionAddress,
        string calldata collectionMetadataUri
    )
        public 
        whenNotPaused()
        onlyFactoryOrOwner()
    {   
        Collection collectionInstance = Collection(collectionAddress);
        require(collectionInstance.hasRole(DEFAULT_MODERATORS_ROLE, msg.sender),
         "only moderators allowed");
        uint tokenId = addressToTokenID[collectionAddress];
        _setTokenUri(tokenId, collectionMetadataUri);
        _setTokenMetadata(tokenId, collectionMetadataUri);
    }

    /// Allows listing a collection in market
    /// @param collectionAddress: the smart contract address for the collection.
    /// @param marketAddress: the smart contract address for the market
    /// @param feeReceiver: who should receive mint fee
    /// @param _supplyLimit: what the supply limit should be.
    /// @param _tokenPrice: token price if not bonded
    /// @param _isBonded: whether its a bonded NFT or not. 
    
    function listCollection(
        address collectionAddress,
        address marketAddress,
        address feeReceiver,
        uint _supplyLimit, 
        uint _tokenPrice,
        bool _isBonded
    )
        public 
        whenNotPaused()
        onlyFactoryOrOwner()
    {   
        Collection collectionInstance = Collection(collectionAddress);
        require(collectionInstance.hasRole(DEFAULT_MODERATORS_ROLE, msg.sender),
         "only moderators allowed");
        uint tokenId = addressToTokenID[collectionAddress];
        require (marketAddresses[tokenId] == address(0), "Already listed");
        MarketMaster market = MarketMaster(marketAddress);
        market.listToken(
            tokenId, 
            feeReceiver, 
            _isBonded,
            _supplyLimit,
            _tokenPrice
        );
    }

    /// Allows anyone to collect a collection if permissions check.
    /// @param collectionAddress: the smart contract address for the collection.
    /// @param receipient: who receives token.

    function collect(address collectionAddress, address receipient)
        public 
        payable
        whenNotPaused()
        returns (string memory)
    {    
        // Check permissions
        uint tokenId = addressToTokenID[collectionAddress];
        require (tokenId <= _tokenIds, "Token does not exists");
        Collection collectionInstance = Collection(collectionAddress);
        require(collectionInstance.hasReadPermission(receipient), 'not allowed');
        // Execute buy if token is listed
        if (marketAddresses[tokenId] != address(0)) {
            MarketMaster globalMarket = MarketMaster(marketAddresses[tokenId]);
            require(tokenSupply[tokenId] < globalMarket.supplyLimit(address(this), tokenId));
            globalMarket.executeBuy{value: msg.value}(tokenId, 1);
        }
        // Mint if checks are OK.
        _mint(receipient, tokenId, 1, "");
        tokenSupply[tokenId] = tokenSupply[tokenId] + 1;
        return _uris[tokenId];
    }

    /// Allows anyone to burn collection NFT
    /// @param collectionAddress: smart contract address for collection
    /// @param amount: amount to burn

    function burn(address collectionAddress, uint256 amount)
        public 
        virtual 
        whenNotPaused()
    {
        uint tokenId = addressToTokenID[collectionAddress];
        require (tokenId <= _tokenIds, "Token does not exists");
        require(balanceOf(msg.sender, tokenId) >= amount, "Insificient balance");
        if (marketAddresses[tokenId] != address(0)){
            MarketMaster globalMarket = MarketMaster(marketAddresses[tokenId]);
            globalMarket.executeSell(tokenId, amount);
        }
        tokenSupply[tokenId] = tokenSupply[tokenId] - 1;
        _burn(msg.sender, tokenId, amount);
    }


    ////////////////////////////
    // Others: Mandatory
    ////////////////////////////

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}



}
