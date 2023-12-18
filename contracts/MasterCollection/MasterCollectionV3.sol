// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 < 0.9.0;


import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../helpers/Params.sol";

/**
 * @title  Master Collection Smart Contract
 * @author Hugo Sanchez & Friend.tech
 * @notice This is the main contract where all versos are minted.
 *         It's basically adapting friend.tech bonding curve mechanism
 *         to ERC1155s as a way to make them liquid. Friend.tech
 *         smart contract can be found here: 
 *         https://basescan.org/address/0xcf205808ed36593aa40a44f10c7f7c2f67d4a4d4#code
 */         

contract MasterCollectionV3 is ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

   
    /////////////////////////////
    // State Variables
    /////////////////////////////

    // Smart contract version 
    uint public constant VERSION = 2;
    // Setting up counter
    uint private _tokenIds;

    // Fees 
    address private protocolFeeDestination;
    uint256 private protocolFeePercent;
    uint256 private creatorFeePercent;
    uint256 private basicPrice;
    
    /////////////////////////////
    // Mappings
    /////////////////////////////


    // Mapping from token ID to  URIs
    mapping(uint256 => string) private _uris;
    // TokenID => Supply
    mapping(uint256 => uint256) public tokenSupply;
    // TokenID => Permissions contract address 
    mapping(uint256 => address) public tokenPermissions;
    // TokenID => Creator
    mapping(uint256 => address) public creator;
    // TokenID => isBonded 
    mapping(uint256 => bool) public isBonded;


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



    ////////////////////////////////
    // Initialize 
    ///////////////////////////////
    function initialize(
        address newOwner
        ) public initializer {
             // Initiate ownable 
            __Ownable_init(newOwner);
            // Initiate ERC1155
            __ERC1155_init("");
            // Initiate UUPS
            __UUPSUpgradeable_init();
    }

    ////////////////////////////////
    // Basic functions get/set
    ///////////////////////////////

    // Get token URI
    function uri(uint tokenID) override public view returns (string memory) {
        return string.concat(_uris[tokenID]);
    }

    // Sets the token metadata
    function _setTokenMetadata(
        uint256 tokenId,
        string memory url
    ) internal virtual returns (string memory) {
        require(bytes(_uris[tokenId]).length == 0, "URI already set");
        _uris[tokenId] = url;
        return _uris[tokenId];
    }

    function setBasicPrice(uint _price) public onlyOwner {
        basicPrice = _price;
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setCreatorFeePercent(uint256 _feePercent) public onlyOwner {
        creatorFeePercent = _feePercent;
    }

    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / 36000;
    }

    function getBuyPrice(uint256 tokenId) public view returns (uint256) {
        return getPrice(tokenSupply[tokenId], 1);
    }

    function getSellPrice(uint256 tokenId) public view returns (uint256) {
        return getPrice(tokenSupply[tokenId] - 1, 1);
    }

    function getBuyPriceAfterFee(uint256 tokenId) public view returns (uint256) {
        uint256 price = getBuyPrice(tokenId);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 creatorFee = price * creatorFeePercent / 1 ether;
        return price + protocolFee + creatorFee;
    }

    function getSellPriceAfterFee(uint256 tokenId) public view returns (uint256) {
        uint256 price = getSellPrice(tokenId);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 creatorFee = price * creatorFeePercent / 1 ether;
        return price - protocolFee - creatorFee;
    }

    /////////////////////////////////
    // Core functionality
    ///////////////////////////////

    function create (
        bytes memory data, 
        string calldata url, 
        address recipient, 
        bool _isBonded
    )
        public
        payable
    {
        _create(data, url, recipient, msg.sender, _isBonded);
    }

    function adminCreate(
        Params.Verso[] calldata versos
    ) 
        public
        payable 
        onlyOwner() 
    {   
        for (uint8 i = 0; i < versos.length; i++){
            _create(
                "0x", 
                versos[i].metadataURI, 
                versos[i].creator, 
                versos[i].creator, 
                versos[i].isBonded
            );
        }
        
    }

    function _create(
        bytes memory data, 
        string calldata url, 
        address recipient, 
        address _creator,
        bool _isBonded
    ) 
        internal 
    {
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        _mint(recipient, newTokenId, 1, data);
        _setTokenMetadata(newTokenId, url);
        creator[newTokenId] = _creator;
        isBonded[newTokenId] = _isBonded;
        _executeBuy(newTokenId);
        emit NewVersoCreated(_creator, newTokenId, url);
    }

    function collect(uint id, address recipient, bytes memory data)
        public 
        payable
        returns (string memory)
    {
        _executeBuy(id);
        _mint(msg.sender, id, 1, data);
        super.safeTransferFrom(msg.sender, recipient, id, 1, data);
        emit NewVersoCollected(msg.sender, id, recipient);
        return _uris[id];
    }    

    function burn(address account, uint256 id, uint256 value)
        public 
        virtual 
    {   
        require(msg.sender == account || msg.sender == owner(), "Can't delete others versos");
        if (isBonded[id] && tokenSupply[id] > 1) _executeSell(id);
        else tokenSupply[id] = 0;
        _burn(account, id, value);
    }

    function _executeBuy(uint256 tokenId) private {
        uint256 supply = tokenSupply[tokenId];
        require(supply > 0 || creator[tokenId] == msg.sender || msg.sender == owner(), "Only the creator can buy the first token");
        uint256 price = isBonded[tokenId] ? getPrice(supply, 1) : basicPrice;
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 creatorFee = isBonded[tokenId] ? price * creatorFeePercent / 1 ether : basicPrice - protocolFee;
        require(msg.value >= price + protocolFee + creatorFee, "Insufficient payment");
        tokenSupply[tokenId] = supply + 1;
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = creator[tokenId].call{value: creatorFee}("");
        require(success1 && success2, "Unable to send funds");
    }

    function _executeSell(uint256 tokenId) private {
        require(balanceOf(msg.sender, tokenId) != 0, "Cant sale what you dont have");
        uint256 supply = tokenSupply[tokenId];
        require(supply > 1, "Cannot sell the last share");
        uint256 price = getPrice(supply - 1, 1);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * creatorFeePercent / 1 ether;
        tokenSupply[tokenId] = supply - 1;
        (bool success1, ) = msg.sender.call{value: price - protocolFee - subjectFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = creator[tokenId].call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }   

    ////////////////////////////
    // Others: Mandatory
    ////////////////////////////

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

     // This is necessary to be able to inherit ACL.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function name() public pure returns (string memory _contractName) {
        return "versos v2";
    }

}
