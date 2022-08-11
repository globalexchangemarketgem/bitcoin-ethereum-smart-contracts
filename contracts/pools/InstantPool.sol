// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import './interfaces/IInstantPool.sol'; 
import '../libraries/SafeMath.sol'; 
import '../erc20/ERC20.sol'; 
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract InstantPool is IInstantPool, ERC20, Ownable, ReentrancyGuard {

    using SafeMath for uint256; 
    address public override teleBTC; 
    uint public override instantPercentageFee; // a number between 0-10000 to show %0.01
    uint public override totalAddedTeleBTC;
    address public override instantRouter;

    constructor(
        address _teleBTC, 
        address _instantRouter,
        uint _instantPercentageFee, 
        string memory _name, 
        string memory _symbol
    ) ERC20(_name, _symbol, 0) { 
        teleBTC = _teleBTC; 
        instantRouter = _instantRouter;
        instantPercentageFee = _instantPercentageFee; 
    }

    /// @notice                               Gives available teleBTC amount                                 
    /// @return                               Available amount of teleBTC that can be borrowed    
    function availableTeleBTC() override public view returns (uint) { 
        return IERC20(teleBTC).balanceOf(address(this)); 
    }

    /// @notice                               Gives the unpaid loans amount
    /// @return                               Amount of teleBTC that has been borrowed but has not been paid back
    function totalUnpaidLoan() override external view returns (uint) { 
        uint _availableTeleBTC = availableTeleBTC();
        return totalAddedTeleBTC >= _availableTeleBTC ? totalAddedTeleBTC - _availableTeleBTC : 0; 
    }  

    /// @notice                 Changes instant router contract address
    /// @dev                    Only owner can call this
    /// @param _instantRouter   The new instant router contract address
    function setInstantRouter(address _instantRouter) external override onlyOwner {
        instantRouter = _instantRouter;
    }
    
    /// @notice                        Changes instant loan fee
    /// @dev                           Only current owner can call this
    /// @param _instantPercentageFee   The new percentage fee    
    function setInstantPercentageFee(uint _instantPercentageFee) external override onlyOwner { 
        instantPercentageFee = _instantPercentageFee; 
    } 

    /// @notice                 Changes teleBTC contract address
    /// @dev                    Only owner can call this
    /// @param _teleBTC         The new teleBTC contract address
    function setTeleBTC(address _teleBTC) external override onlyOwner {
        teleBTC = _teleBTC;
    } 

    /// @notice               Adds liquidity to instant pool
    /// @dev                           
    /// @param _user          Address of user who receives instant pool token        
    /// @param _amount        Amount of liquidity that user wants to add   
    /// @return               Amount of instant pool token that user receives
    function addLiquidity(address _user, uint _amount) external nonReentrant override returns (uint) {
        require(_amount > 0, "InstantPool: input amount is zero"); 
        uint instantPoolTokenAmount; 
        // Transfers teleBTC from user 
        IERC20(teleBTC).transferFrom(msg.sender, address(this), _amount); 
        if (totalAddedTeleBTC == 0 || totalSupply() == 0) { 
            instantPoolTokenAmount = _amount; 
        } else { 
            instantPoolTokenAmount = _amount*totalSupply()/totalAddedTeleBTC; 
        }
        totalAddedTeleBTC = totalAddedTeleBTC + _amount; 
        // Mints instant pool token for user 
        _mint(_user, instantPoolTokenAmount); 
        emit AddLiquidity(_user, _amount, instantPoolTokenAmount); 
        return instantPoolTokenAmount; 
    }

    /// @notice               Adds liquidity to instant pool without minting instant pool tokens
    /// @dev                  Updates totalAddedTeleBTC (transferring teleBTC directly does not update it)
    /// @param _amount        Amount of liquidity that user wants to add   
    /// @return               True if liquidity is added successfully
    function addLiquidityWithoutMint(uint _amount) external nonReentrant override returns (bool) {
        require(_amount > 0, "InstantPool: input amount is zero"); 
        // Transfers teleBTC from user 
        IERC20(teleBTC).transferFrom(msg.sender, address(this), _amount); 
        totalAddedTeleBTC = totalAddedTeleBTC + _amount; 
        emit AddLiquidity(msg.sender, _amount, 0); 
        return true; 
    }  
    
    /// @notice                               Removes liquidity from instant pool
    /// @dev                           
    /// @param _user                          Address of user who receives teleBTC       
    /// @param _instantPoolTokenAmount        Amount of instant pool token that is burnt  
    /// @return                               Amount of teleBTC that user receives
    function removeLiquidity(address _user, uint _instantPoolTokenAmount) external nonReentrant override returns (uint) {
        require(_instantPoolTokenAmount > 0, "InstantPool: input amount is zero");
        require(balanceOf(msg.sender) >= _instantPoolTokenAmount, "InstantPool: balance is not sufficient"); 
        uint teleBTCAmount = _instantPoolTokenAmount*totalAddedTeleBTC/totalSupply();
        totalAddedTeleBTC = totalAddedTeleBTC - teleBTCAmount; 
        IERC20(teleBTC).transfer(_user, teleBTCAmount); 
        _burn(msg.sender, _instantPoolTokenAmount); 
        emit RemoveLiquidity(msg.sender, teleBTCAmount, _instantPoolTokenAmount); 
        return teleBTCAmount; 
    } 

    /// @notice                               Gives loan to user
    /// @dev                                  Only instant router contract can call this
    /// @param _user                          Address of user who wants loan 
    /// @param _amount                        Amount of requested loan
    /// @return                               Amount of given loan after reducing the fee 
    function getLoan(address _user, uint _amount) nonReentrant override external returns (bool) { 
        require(msg.sender == instantRouter, "InstantPool: sender is not allowed");
        require(availableTeleBTC() >= _amount, "InstantPool: liquidity is not sufficient"); 
        // Instant fee increases the total teleBTC amount
        uint instantFee = _amount*instantPercentageFee/10000;
        // totalAddedTeleBTC = totalAddedTeleBTC + instantFee; 
        IERC20(teleBTC).transfer(_user, _amount); 
        emit InstantLoan(_user, _amount, instantFee); 
        return true; 
    } 

}