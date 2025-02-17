// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.4;

import "./interfaces/ITeleBTC.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TeleBTC is ITeleBTC, ERC20, Ownable, ReentrancyGuard {
 
    modifier onlyMinter() {
        require(isMinter(_msgSender()), "TeleBTC: only minters can mint");
        _;
    }

    modifier onlyBurner() {
        require(isBurner(_msgSender()), "TeleBTC: only burners can burn");
        _;
    }

    modifier nonZeroValue(uint _value) {
        require(_value > 0, "TeleBTC: value is zero");
        _;
    }

    // Public variables
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;

    uint public maxMintLimit;      // Maximum mint limit per epoch
    uint public lastMintLimit;          // Current mint limit in last epoch, decrease by minting in an epoch
    uint public epochLength;            // Number of blocks in every epoch
    uint public lastEpoch;              // Epoch number of last mint transaction


    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        maxMintLimit = 10 ** 8;
        lastMintLimit = 10 ** 8;
        epochLength = 2000;
    }

    function renounceOwnership() public virtual override onlyOwner {}

    function decimals() public view virtual override(ERC20, ITeleBTC) returns (uint8) {
        return 8;
    }

    /**
     * @dev change maximum mint limit per epoch.
     */
    function setMaxMintLimit(uint _mintLimit) public override onlyOwner {
        emit NewMintLimit(maxMintLimit, _mintLimit);
        maxMintLimit = _mintLimit;
    }

    /**
     * @dev change blocks number per epoch.
     */
    function setEpochLength(uint _length) public override onlyOwner nonZeroValue(_length) {
        emit NewEpochLength(epochLength, _length);
        epochLength = _length;
    }

    /**
     * @dev Check if an account is minter.
     * @return bool
     */
    function isMinter(address account) internal view returns (bool) {
        require(account != address(0), "TeleBTC: account is the zero address");
        return minters[account];
    }

    /// @notice                Check if an account is burner    
    /// @param  account        The account which intended to be checked
    /// @return bool
    function isBurner(address account) internal view returns (bool) {
        require(account != address(0), "TeleBTC: account is the zero address");
        return burners[account];
    }

    /// @notice                Adds a minter
    /// @dev                   Only owner can call this function
    /// @param  account        The account which intended to be added to minters
    function addMinter(address account) external override onlyOwner {
        require(!isMinter(account), "TeleBTC: account already has role");
        minters[account] = true;
        emit MinterAdded(account);
    }

    /// @notice                Removes a minter
    /// @dev                   Only owner can call this function
    /// @param  account        The account which intended to be removed from minters
    function removeMinter(address account) external override onlyOwner {
        require(isMinter(account), "TeleBTC: account does not have role");
        minters[account] = false;
        emit MinterRemoved(account);
    }

    /// @notice                Adds a burner
    /// @dev                   Only owner can call this function
    /// @param  account        The account which intended to be added to burners
    function addBurner(address account) external override onlyOwner {
        require(!isBurner(account), "TeleBTC: account already has role");
        burners[account] = true;
        emit BurnerAdded(account);
    }

    /// @notice                Removes a burner
    /// @dev                   Only owner can call this function
    /// @param  account        The account which intended to be removed from burners
    function removeBurner(address account) external override onlyOwner {
        require(isBurner(account), "TeleBTC: account does not have role");
        burners[account] = false;
        emit BurnerRemoved(account);
    }

    /// @notice                Burns TeleBTC tokens of msg.sender
    /// @dev                   Only burners can call this
    /// @param _amount         Amount of burnt tokens
    function burn(uint _amount) external nonReentrant onlyBurner override returns (bool) {
        _burn(_msgSender(), _amount);
        emit Burn(_msgSender(), _msgSender(), _amount);
        return true;
    }

    /// @notice                Mints TeleBTC tokens for _receiver
    /// @dev                   Only minters can call this
    /// @param _receiver       Address of token's receiver
    /// @param _amount         Amount of minted tokens
    function mint(address _receiver, uint _amount) external nonReentrant onlyMinter override returns (bool) {
        require(_amount <= maxMintLimit, "TeleBTC: mint amount is more than maximum mint limit");
        require(checkAndReduceMintLimit(_amount), "TeleBTC: reached maximum mint limit");

        _mint(_receiver, _amount);
        emit Mint(_msgSender(), _receiver, _amount);
        return true;
    }

    /// @notice                Check if can mint new tokens and update mint limit
    /// @param _amount         Desired mint amount
    function checkAndReduceMintLimit(uint _amount) private returns (bool) {
        uint currentEpoch = block.number / epochLength;
        
        if (currentEpoch == lastEpoch) {
            if (_amount > lastMintLimit)
                return false;
            lastMintLimit -= _amount;
        } else {
            lastEpoch = currentEpoch;
            lastMintLimit = maxMintLimit - _amount;
        }
        return true;
    }
}
