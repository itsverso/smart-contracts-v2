//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";


/**
 * @title  Follow Registry Smart Contract
 * @author Hugo Sanchez
 * @notice Every user has a follow-NFT (open-edition, free, ERC1155 NFT)
 *         Following is just minting one. Follow tokenID corresponds to the user
 *         tokenID on the Profile registry. 
 */

contract FollowRegistry is 

    OwnableUpgradeable, 
    ERC1155Upgradeable, 
    UUPSUpgradeable,
    PausableUpgradeable 
{
 
    address profileRegistryAddress;

    ////////////////////////////////
    // Initialize 
    ///////////////////////////////
    function initialize(
        address _owner,
        address _profileRegistry
       
        ) public initializer {
            // Initiate ownable 
            __Ownable_init(_owner);
            // Initialize ERC1155
            __ERC1155_init("");
            // UUPS
            __UUPSUpgradeable_init();
             // Initiate pausable
            __Pausable_init_unchained();
            // Set address
            profileRegistryAddress = _profileRegistry;
    }

    // Basic modifier
    modifier onlyRegistry() {
        require(
            msg.sender == profileRegistryAddress,
            "Only moderators allowed"
        );
        _;
    }


    ////////////////////////////////
    // Basics 
    ///////////////////////////////

    // Pause SC
    function pause() external onlyOwner {
        _pause();
    }
    
    // Unpause SC
    function unpause() external onlyOwner {
        _unpause();
    }

    // Smart contract name. 
    function name() public pure returns (string memory) {
        return "Verso Follow Registry";
    }

    // Smart contract symbol
    function symbol() public pure returns (string memory) {
        return "VFR";
    }

    // Returns the current Profile Registry address
    function getRegistry() public view returns (address) {
        return profileRegistryAddress;
    }

    // Sets a new Profile Registry address
    function setRegistry(address _newAddress) public onlyOwner() {
        profileRegistryAddress = _newAddress;
    }


    /////////////////////////////////
    // Core functionality
    ///////////////////////////////


    /**
     * @param tokenId - The token ID for the profile on ProfileRegistry. 
     * @param userAddress - The address of the user who just created a profile.
     *  This function gets called by the ProfileRegistry every time someone 
     *  registers a new profile. The follow token ID corresponds to the 
     *  profile token ID.
     */
    function register (uint tokenId, address userAddress) public onlyRegistry(){
        _mint(userAddress, tokenId, 1, "0x");
    }

     /**
     * @param tokenId - The token ID for the profile you want to follow. 
     * This is a simple "mint" function where a user (msg.sender) 
     * mints a "follow" NFT for a given Profile. A follow is simply 
     * an ERC1155 token, without metadata, keeping it super simple ATM      
     */
    function follow(uint tokenId) public {
        require(balanceOf(msg.sender, tokenId) < 1, 'Already a follower');
        _mint(msg.sender, tokenId, 1, "0x");
    }  

    /**
     * @param tokenId - The token ID for the profile you want to unfollow. 
     * This is a simple "burn" function where a user (msg.sender) 
     * burns a "follow" NFT for a given Profile      
     */ 
    function unfollow(uint tokenId) public {
        require(balanceOf(msg.sender, tokenId) > 0, 'Not a follower');
        _burn(msg.sender, tokenId, 1);
    }
  
    ////////////////////////////
    // Others: Mandatory
    ////////////////////////////

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

}
