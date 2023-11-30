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

contract MarketMaster is 
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
    uint256 private protocolFeePercent; // 005000000000000000
    uint256 private creatorFeePercent;  // 005000000000000000
    uint256 private basicPrice; // 000077777777777777
    
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
            uint256 _feePercent,
            uint256 _creatorPercent,
            uint _basicPrice
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
            protocolFeePercent = _feePercent; // 005000000000000000
            // Set creator fee percent
            creatorFeePercent = _creatorPercent; // 005000000000000000
            // Basic price 
            basicPrice = _basicPrice; // 000777777777777777
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

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner() {
        protocolFeePercent = _feePercent;
    }

    function setCreatorFeePercent(uint256 _feePercent) public onlyOwner() {
        creatorFeePercent = _feePercent;
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
        creator[msg.sender][_tokenId] = _creator;
        tokenSupply[msg.sender][_tokenId] = 0;
        supplyLimit[msg.sender][_tokenId] = _isBonded ? MAX_INT : _supplyLimit;
        tokenPrice[msg.sender][_tokenId] = _isBonded ? 0 : _tokenPrice;
    }

    ///////////////////////////////// 
    // Bonding curve price getters
    ///////////////////////////////// 

    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / 36000;
    }

    function getBuyPrice(address _collection, uint256 _tokenId, uint _amount) 
        public view returns (uint256 price) {
        return getPrice(tokenSupply[_collection][_tokenId], _amount); 
    }

    function getSellPrice(address _collection, uint256 _tokenId, uint _amount) 
        public view returns (uint256 price) {
        return getPrice(tokenSupply[_collection][_tokenId] - _amount, _amount);
    }

    function getBuyPriceAfterFee(address _collection, uint256 _tokenId, uint _amount) 
        public view returns (uint256) 
    {
        uint256 price = getBuyPrice(_collection, _tokenId, _amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 creatorFee = price * creatorFeePercent / 1 ether;
        return price + protocolFee + creatorFee;
    }

    function getSellPriceAfterFee(address _collection, uint256 _tokenId, uint _amount) 
        public view returns (uint256) 
    {
        uint256 price = getSellPrice(_collection, _tokenId, _amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 creatorFee = price * creatorFeePercent / 1 ether;
        return price - protocolFee - creatorFee;
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

    function executeBuy(uint _tokenId, uint _amount) 
        public 
        payable 
        whenNotPaused()
    {
        if (isBonded[msg.sender][_tokenId]) _executeBondedBuy(msg.sender, _tokenId, _amount);
        else _executeRegularBuy(msg.sender, _tokenId, _amount);
    }

     /**
     * Checks token type (bonded or not) and executes trade
     * on behalf of collections (collection is the caller (msg.sender))
     * @param _tokenId: the ID of the token
     * @param _amount: amount to sell
     */

    function executeSell(uint _tokenId, uint _amount) 
        public 
        payable
        whenNotPaused() 
    {
        if (isBonded[msg.sender][_tokenId]) _executeBondedSell(msg.sender, _tokenId, _amount);
    }

    /**
     * Executes trade in case token is NOT bonded
     * @param _collection: collection SC address
     * @param _tokenId: the ID of the token
     * @param _amount: amount to sell
     */
    function _executeRegularBuy(
        address _collection, 
        uint _tokenId, 
        uint _amount
    ) 
        private 
    {
        uint totalPrice = tokenPrice[_collection][_tokenId] * _amount;
        require(msg.value > totalPrice);
        uint platformFee = totalPrice / 20;
        uint creatorFee = totalPrice - platformFee;
        (bool success1, ) = protocolFeeDestination.call{value: platformFee}("");
        (bool success2, ) = creator[_collection][_tokenId].call{value: creatorFee}("");
        require(success1 && success2, "Error executing buy");
    }

    /**
     * Executes trade in case token IS bonded
     * @param _collection: collection SC address
     * @param _tokenId: the ID of the token
     * @param _amount: amount to sell
     */
    function _executeBondedBuy(
        address _collection,
        uint256 _tokenId, 
        uint _amount
    ) 
        private 
    {
        uint256 supply = tokenSupply[_collection][_tokenId];
        uint256 price = getPrice(supply, _amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 creatorFee = price * creatorFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + creatorFee, "insufficient payment");
        tokenSupply[_collection][_tokenId] = supply + _amount;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = creator[_collection][_tokenId].call{value: creatorFee}("");
        require(success1 && success2, "Error executing buy");
    }

    /**
     * Executes trade in case token IS bonded
     * @param _collection: collection SC address
     * @param _tokenId: the ID of the token
     * @param _amount: amount to sell
     */
    function _executeBondedSell(
        address _collection,
        uint256 _tokenId, 
        uint _amount
    )  
        private
    {   
        uint256 supply = tokenSupply[_collection][_tokenId];
        require(supply > 1, "Cannot sell the last share");
        uint256 price = getPrice(supply - _amount, _amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * creatorFeePercent / 1 ether;
        tokenSupply[_collection][_tokenId] = supply - _amount;
        (bool success1, ) = _collection.call{value: price - protocolFee - subjectFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = creator[_collection][_tokenId].call{value: subjectFee}("");
        require(success1 && success2 && success3, "Error executing sell");
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
