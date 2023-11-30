// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "contracts/MarketMaster.sol";
import "contracts/helpers/RegularBalanceOf.sol";
import "contracts/helpers/ERC1155BalanceOf.sol";

import "hardhat/console.sol";
/**
 * @title  Collection Smart Contract
 * @author Hugo Sanchez
 * @notice This is the new collection implementation. It gives users 
 *         more control over their work: they own the collection and tokens.
 *         It also allows for social features: members & moderators 
 *         as well as read/write permissions for both the collection itself and its tokens.
 *         This will allow for all sorts experiences to be built on top (!).
 */

contract Collection is 

    ERC1155Upgradeable, 
    AccessControlEnumerableUpgradeable, 
    ERC1155HolderUpgradeable,
    PausableUpgradeable 

{

    // Smart contract version 
    uint public constant VERSION = 1;
    // Collection name
    string public name;
    // Counters
    uint private _tokenIds;
    // Read/Collect type: 0-Open, 1-Gated
    uint8 public readType;
    // Write/Mint type: 0-Open (everyone!), 1-Only Members, 2-Members + Gated
    uint8 public writeType;
    // Address of the ERC20 or ERC721 smart contract to verify.
    address public collectionPermissions;
    // Minimum balance user needs to have to collec items.
    uint public minimumBalance;
    // Max integer
    uint256 internal constant MAX_INT = 2**256 - 1;
    // Base url - Necessary?
    string internal baseURI = "https://arweave.net/";
    // Role MODERATOR
    bytes32 internal constant DEFAULT_MODERATORS_ROLE = keccak256("MODERATORS");
    // Role MEMBER
    bytes32 internal constant DEFAULT_MEMBERS_ROLE = keccak256("MEMBERS");
    

    // Mapping from token ID to  URIs
    mapping(uint256 => string) private _uris;
    // TokenID => Supply
    mapping(uint256 => uint256) public tokenSupply;
    // TokenID => Permissions contract address 
    mapping(uint256 => address) public tokenPermissions;
    // TokenID => Market address
    mapping(uint256 => address) public marketAddresses;
    // TokenID => Creator
    mapping(uint256 => address) public creator;
    // TokenID => isBonded 
    mapping(uint256 => bool) public isListed;    
    
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
    modifier onlyModerators() {
        require(
            hasRole(DEFAULT_MODERATORS_ROLE, msg.sender),
            "only moderators allowed"
        );
        _;
    }

    // Writers
    modifier onlyWriters() {
        require(
            hasWritePermission(msg.sender),
            "no write permission"
        );
        _;
    }

    // Readers
    modifier onlyReaders() {
        require(
            hasReadPermission(msg.sender),
            "no read permission"
        );
        _;
    }


    ////////////////////////////////
    // Initialize 
    ///////////////////////////////
    function initialize(
        string memory _name,
        address _owner,
        uint8 _readType,
        uint8 _writeType,
        address _collectionPermissions,
        uint _minimumBalance
    ) 
        public 
        initializer 
    {
            console.log('WE ARE HERE TOO');
            // Set contract name
            name = _name;
            // Instantiate receiver
            __ERC1155Holder_init();
            __ERC1155_init("");
            // Set access control module 
            __AccessControlEnumerable_init();
            // Initiate pausable
            __Pausable_init_unchained();
            // For token gated collections
            readType = _readType;
            writeType = _writeType;
            collectionPermissions = _collectionPermissions;
            minimumBalance = _minimumBalance;
            // Set up initial roles.
            _grantRole(DEFAULT_ADMIN_ROLE, _owner);
            _grantRole(DEFAULT_MODERATORS_ROLE, _owner);
            console.log('WE NOT ARE HERE');
            _grantRole(DEFAULT_MEMBERS_ROLE, _owner);
            _setRoleAdmin(DEFAULT_MODERATORS_ROLE, DEFAULT_MODERATORS_ROLE);
            _setRoleAdmin(DEFAULT_MEMBERS_ROLE, DEFAULT_MODERATORS_ROLE);
    }


    ////////////////////////////////
    // Basic functions get/set
    ///////////////////////////////

    // Pausing
    function pause() external onlyModerators() {
        _pause();
    }
 
    // Unpausing
    function unpause() external onlyModerators() {
        _unpause();
    }

    // Simplifies checking if user is moderator.
    function isModerator(address user) public view returns (bool) {
        return hasRole(DEFAULT_MODERATORS_ROLE, user);
    }

    // Get token URI
    function uri(uint tokenID) override public view returns (string memory) {
        return string.concat(baseURI, _uris[tokenID]);
    }

    // Sets the token metadata
    function _setTokenMetadata(
        uint256 tokenId,
        string memory url
    ) 
        internal 
        virtual 
        whenNotPaused()
        returns (string memory) 
    {
        require(bytes(_uris[tokenId]).length <= 20, "URI already set");
        _uris[tokenId] = url;
        return _uris[tokenId];
    }


    /////////////////////////////////
    // Core functionality
    ///////////////////////////////


    /// @param url: metadata uri for token
    /// @param _receipient: who will receive token once minted
    /// @param _permissions: smart contract address for permissions
    /// @param _marketAddress: global market smart contract address
    /// @param _supplyLimit: how many tokens will ever exists 
    /// @param _tokenPrice: what the price will be for the token 
    /// @param _isBonded: wether to attach the bonding curve or not  
    /// - Entry point to set all the parameters and mint first edtion.


    function create(
        string calldata url,
        address _receipient,
        address _permissions,
        address _marketAddress,
        uint _supplyLimit,
        uint _tokenPrice,
        bool _isListed,
        bool _isBonded
    )
        public 
        whenNotPaused()
        onlyWriters()
    {   
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        tokenPermissions[newTokenId] = _permissions;

        if (_isListed) {
            isListed[newTokenId] = _isListed;
            marketAddresses[newTokenId] = _marketAddress;
            MarketMaster globalMarket = MarketMaster(_marketAddress);
            globalMarket.listToken(newTokenId, msg.sender, _isBonded, _supplyLimit, _tokenPrice);

            if (_isBonded) {
                globalMarket.executeBuy(newTokenId, 1);
            }
        }

        tokenSupply[newTokenId] = 1;
        _mint(_receipient, newTokenId, 1, "");
        _setTokenMetadata(newTokenId, url);
    }

    /// @param id: token id
    /// @param receipient: who's going to receive the token 
    /// @param amount: amount of tokens to mint 
    /// - Executes token collecting:
    ///     1. Checks that user has collection & token permissions
    ///     2. Checks wether it's listed or not
    ///     3. If listed it executes buy, if not, just mints (it's free);

    function collect(
        uint id, 
        address receipient, 
        uint amount
    )
        public 
        payable
        whenNotPaused()
        onlyReaders()
    {

        require(id <= _tokenIds, "Token does not exists");
        require(_checkTokenPermissions(id, msg.sender) == true, "No mint permission");

        if (isListed[id]) {
            MarketMaster globalMarket = MarketMaster(marketAddresses[id]);
            require(tokenSupply[id] < globalMarket.supplyLimit(address(this), id));
            globalMarket.executeBuy{value: msg.value}(id, amount);
        }

        _mint(receipient, id, 1, "");
        tokenSupply[id] = tokenSupply[id] + 1;
    }

    /// @param tokenId: token ID.
    /// @param amount: amount to burn
    /// If is bonded executes sell, 
    /// if not, just burns
    function burn(uint256 tokenId, uint256 amount)
        public 
        payable 
        whenNotPaused()
    {   
        require(balanceOf(msg.sender, tokenId) >= amount, "Insificient balance");
        if (isListed[tokenId]){
            MarketMaster globalMarket = MarketMaster(marketAddresses[tokenId]);
            globalMarket.executeSell(tokenId, amount);
        }
        _burn(msg.sender, tokenId, amount);
        tokenSupply[tokenId] = tokenSupply[tokenId] - 1;
    }

    /////////////////////////////////
    // Permissions
    ///////////////////////////////

    /// CONTRACT level READ permissions
    function hasReadPermission(address user) public view returns (bool hasPermission) {
        if (readType == 0) return true;
        else if (readType == 1) {
            if (super.hasRole(DEFAULT_MEMBERS_ROLE, user)) return true;
            else return RegularBalanceOf(collectionPermissions).balanceOf(user) >= minimumBalance;
        }
    }

    /// CONTRACT level WRITE permissions
    function hasWritePermission(address user) public view returns (bool hasPermission) {
        if (writeType == 0) return true;
        else if (writeType == 1) return super.hasRole(DEFAULT_MODERATORS_ROLE, user);
        else if (writeType == 2) {
            if (super.hasRole(DEFAULT_MEMBERS_ROLE, user)) return true;
            else return RegularBalanceOf(collectionPermissions).balanceOf(user) >= minimumBalance;
        }
    }

    /// TOKEN level COLLECT permissions 
    function _checkTokenPermissions(uint tokenId, address account) private view returns (bool check){
        if (tokenPermissions[tokenId] != address(0)){
            if (IERC165(tokenPermissions[tokenId]).supportsInterface(0xd9b67a26)){
                ERC1155BalanceOf permissionsContract = ERC1155BalanceOf(tokenPermissions[tokenId]);
                return permissionsContract.balanceOf(account, tokenId) > 0;
            } else {
                RegularBalanceOf permissionsContract = RegularBalanceOf(tokenPermissions[tokenId]);
                return permissionsContract.balanceOf(account) > 0;
            }
        }
    }


    ////////////////////////////
    // Others: Mandatory
    ////////////////////////////

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, ERC1155HolderUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address operator,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4 ret) {
        if (hasRole(DEFAULT_MODERATORS_ROLE, operator)){
            return this.onERC1155Received.selector;
        }
    }

    function onERC1155BatchReceived(
        address operator,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4 ret) {
        if (hasRole(DEFAULT_MODERATORS_ROLE, operator)){
            return this.onERC1155BatchReceived.selector;
        }
    }


}
