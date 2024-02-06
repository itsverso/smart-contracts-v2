// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 < 0.9.0;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "hardhat/console.sol";
/**
 * @title  VERSO Market Smart Contract
 * @author Hugo Sanchez 
 * @notice This smart contract allows users to "list" their tokens for selling.
 *         It centralizes all of the buying/seliing logic allowing collection smart 
 *         contracts to be much leaner and focus on member management & permissions.
 *         Also, since collections will be NFTs too, the contract allows to buy/sell
 *         collections too. One use case for that is charging to access private galleries.
 */ 

contract SimpleMarketMaster is 
    Initializable, 
    OwnableUpgradeable, 
    UUPSUpgradeable, 
    PausableUpgradeable
{

    /////////////////////////////
    // Constants
    /////////////////////////////

    // Smart contract version 
    uint public constant VERSION = 1;
    uint256 internal constant MAX_INT = 2**256 - 1;

    // Fees 
    address private protocolFeeDestination; 
    uint256 private simpleFeePercent; // 10
    uint256 private basePrice; // 000055555555555555
    
    /////////////////////////////
    // Mappings
    /////////////////////////////

    // Collection Address => TokenID => Supply
    mapping(address => mapping(uint256 => uint256)) public tokenSupply;
    // Collection Address => TokenID => Creator
    mapping(address => mapping(uint256 => address)) public creator;
    // TokenID => Supply limit
    mapping(address => mapping(uint256 => uint)) public supplyLimit;
    // TokenID => Price - only if not bonded
    mapping(address => mapping(uint256 => uint)) public tokenPrice;
    // TokenID => isBonded 
    mapping(address => mapping(uint256 => bool)) public isBonded;

    ////////////////////////////////
    // Initialize 
    ///////////////////////////////
    function initialize(
            address _owner,
            address _feeDestination,
            uint _basePrice
        ) public initializer {
            // Initialize ownable
            __Ownable_init(_owner);
            // Initiate UUPS
            __UUPSUpgradeable_init();
            // Initiate pausable
            __Pausable_init_unchained();
            // Set platform fee destination
            protocolFeeDestination = _feeDestination;
            // Set protocol fee percent 
            simpleFeePercent = 10;
            // Basic price 
            basePrice = _basePrice; // 000055555555555555
    }

    ////////////////////////////////
    // Basic functions get/set
    ///////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }
 
    function unpause() external onlyOwner {
        _unpause();
    }

    function getTokenSupply(address _collection, uint _tokenId) 
        public view returns (uint) {
        return tokenSupply[_collection][_tokenId];
    }

    function setFeeDestination(address _feeDestination) public onlyOwner() {
        protocolFeeDestination = _feeDestination;
    }

    function setBasePrice(uint newPrice) public onlyOwner() {
        basePrice = newPrice;
    }

    function setSimpleFeePercent(uint newFeePercent) public onlyOwner() {
        simpleFeePercent = newFeePercent;
    }

    ////////////////////////////////
    // Listing: entrypoint
    ///////////////////////////////

    /**
     * Only collections can call this entrypoint.
     * The contract tracts the tokenId and its attributes
     * This function is the entrypoint
     * @param _tokenId: the token id about to be minted.
     * @param _creator: who's the creator for that token.
     * @param _isBonded: whether it's bonded or not.
     * @param _supplyLimit: token supply limit if not bonded.
     * @param _tokenPrice: token price if not bonded.
     */
    function listToken(
        uint _tokenId, 
        address _creator, 
        bool _isBonded,
        uint _supplyLimit,
        uint _tokenPrice

    ) 
        public 
    {   
        isBonded[msg.sender][_tokenId] = _isBonded;
        creator[msg.sender][_tokenId] = _creator;
        tokenSupply[msg.sender][_tokenId] = _isBonded ? 0 : 1;
        supplyLimit[msg.sender][_tokenId] = _isBonded ? MAX_INT : _supplyLimit;
        tokenPrice[msg.sender][_tokenId] = _isBonded ? 0 : _tokenPrice;
    }

    ///////////////////////////////// 
    // Price getters
    ///////////////////////////////// 

    /**
     * @param _collection: smart contract address for token 
     * @param _tokenId: token id within collection
     * @param _amount: amount to be bought
     * Super simple function returns price for a token. 
     * Price is always token price + base price.
     */
    function getBuyPrice(address _collection, uint256 _tokenId, uint _amount) 
        public 
        view 
        returns (uint256 price) 
    {   
        return ((tokenPrice[_collection][_tokenId] + basePrice) * _amount);
    }

     /**
     * @param _collection: smart contract address for token 
     * @param _tokenId: token id within collection
     * @param _amount: amount to be bought
     * Super simple function returns price for a token. 
     * Price is always token price + base price.
     */
    function getBuyPriceAfterFee(address _collection, uint256 _tokenId, uint _amount) 
        public 
        view 
        returns (uint256 price) 
    {   
        return getBuyPrice(_collection, _tokenId, _amount);
    }


    ////////////////////////////////
    // Executes
    ///////////////////////////////

    /**
     * Checks token type (bonded or not) and executes trade
     * on behalf of collections (collection is the caller (msg.sender))
     * @param _tokenId: the ID of the token
     * @param _amount: amount to buy
     */

    function executeBuy(uint _tokenId, uint _amount, address _referer) 
        public 
        payable 
        whenNotPaused()
    {   
        _executeRegularBuy(msg.sender, _referer, _tokenId, _amount);
    }

    /**
     * Executes trade in case token is NOT bonded. 
     * Platform takes 10%. Referer takes 10%;
     * @param _collection: collection SC address
     * @param _referer: user who recomends gets a cut
     * @param _tokenId: the ID of the token
     * @param _amount: amount to sell
     */
    function _executeRegularBuy(
        address _collection, 
        address _referer,
        uint _tokenId, 
        uint _amount
    ) 
        private 
    {
        uint totalPrice = (tokenPrice[_collection][_tokenId] + basePrice) * _amount;
        require(msg.value > totalPrice, "Insufficient funds");
        uint protocolFee = totalPrice / 10;
        uint refererFee = _referer == address(0) ? 0 : totalPrice / 10;
        uint creatorFee = totalPrice - protocolFee - refererFee;
        tokenSupply[_collection][_tokenId] = tokenSupply[_collection][_tokenId] + _amount;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = creator[_collection][_tokenId].call{value: creatorFee}("");
        (bool success3, ) = _referer.call{value: refererFee}("");
        require(success1 && success2 && success3, "Error executing regular buy");
    }

    ////////////////////////////
    // Others: Mandatory
    ////////////////////////////

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner()
        override
    {}

}
