//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/*@ Title LexcashApp
*@autor Ifeanyi Paul Ezendukaku, ezendukakuifeanyi@gmail.com
*@ Notice This a dex smart contract in solidity for swapping tokens to USDT
* This contract acs as its own liquidity pool, managed by the owner
*/

contract LexcashApp {
   using SafeERC20 for IERC20;
   //----state vairables-----
   //The ERC20 token been accepted
   IERC20 public immutable acceptedToken;
   
   //The USDT token
   IERC20 public immutable usdtToken;

   //The chainlink price feed
   AggregatorV3Interface internal tokenUsdtPriceFeed;
   
   //The owner of the contract
   address public owner;
   bool public isPaused;

   //-----events-------
   event Swapped (
      address indexed user,
      uint256 amountIn,
      uint256 usdtAmountOut
   );

   event LiquidityAdded(uint256 acceptedTokenAmount, uint256 usdtAmount);
   event LiquidityRemoved(uint256 acceptedTokenAmount, uint256 usdtAmount);
   event Paused (bool status);
    
   //----modifier------
   modifier onlyOwner() {
      require(msg.sender == owner, "Caller is not the owner");
      _;
   }

   modifier whenNotPaused() {
      require(!isPaused, "Contract is paused");
      _;
   }

   //-----functions-----------
   /*
   *@param _acceptedTokenAddress- The address of the accepted token e.g WETH
   *@param _usdtTokenAddress - The address of the ERC20 usdt token
   *@param _tokenUsdtPriceFeedAddress - The address of the chainlink price feed for token to usdt
   */

   /*
   _acceptedTokenAddress = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81
   _usdtTokenAddress     = 0x36484e9f776d9696ff1bf2cb2c1d6faa2da7b37b
   _acceptedTokenUsdtPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306
   * Use the above addresses to deploy the contract
   */
      constructor(
      address _acceptedTokenAddress,
      address _usdtTokenAddress,
      address _acceptedTokenUsdtPriceFeed
   ) {
      owner = msg.sender;
      acceptedToken = IERC20 (_acceptedTokenAddress);
      usdtToken = IERC20(_usdtTokenAddress);
      tokenUsdtPriceFeed = AggregatorV3Interface(_acceptedTokenUsdtPriceFeed);
   }

   /*
   @notice - Swaps the users acceptedToken with the contract's usdtToken
   @dev - The user must first approve the contract to spend their tokens
   @param - _amountToSwap - The amount of acceptedToken the user is willing to swap
   */
   function swapTokenToUsdt(uint256 _amountToSwap) external whenNotPaused {
      require(_amountToSwap > 0, "Amount to swap must be greater than zero");
     
      // Fetch the latest price from the chainlink oracle
      (, int256 price , , ,) = tokenUsdtPriceFeed.latestRoundData();
      uint8 oracleDecimals = tokenUsdtPriceFeed.decimals();

      //Get token dynamically
       IERC20Metadata acceptedTokenMetadata = IERC20Metadata(address(acceptedToken));
       uint8 acceptedTokenDecimals = acceptedTokenMetadata.decimals();
    
       IERC20Metadata usdtMetadata = IERC20Metadata(address(usdtToken));
       uint8 usdtDecimals = usdtMetadata.decimals();
   
      //Calculate the amount of USDT to send out,handling different decimal precisions
      //Formula: amountOut = (amountIn * price) / 10^(input_decimals)
      //To avoid precision loss, we adjust for all decimals at once.
      uint256 usdtAmountOut = (_amountToSwap * uint256(price) * (10**usdtDecimals)) /
                               ((10**acceptedTokenDecimals) * (10**oracleDecimals));
      require(usdtToken.balanceOf(address(this)) >= usdtAmountOut, "Insufficient USDT liquidity");

      // Pull the acceptedToken from the user into this contract
      acceptedToken.safeTransferFrom(msg.sender,address(this), _amountToSwap);

      //send the USDT from this contract to the user
      usdtToken.safeTransfer(msg.sender, usdtAmountOut);

      emit Swapped(msg.sender, _amountToSwap, usdtAmountOut);

   }
   
   // ---------Admin Functions ---------
   /**
   * @notice Owner can add liquidity to the contract
   * @dev The owner must first approve this contract to spend their tokens
   */
   function addLiquidity(
      uint256 _acceptedTokenAmount,
      uint256 _usdtAmount
   ) external onlyOwner {
       require(_acceptedTokenAmount > 0 || _usdtAmount > 0, "Must add some liquidity");
       if (_acceptedTokenAmount > 0) {
           acceptedToken.safeTransferFrom(msg.sender,address(this), _acceptedTokenAmount);
       }

       if (_usdtAmount > 0) {
         usdtToken.safeTransferFrom(msg.sender, address(this), _usdtAmount);
       }
       emit LiquidityAdded(_acceptedTokenAmount, _usdtAmount);
   }

   /*
   * @notice Owner can ermove liquidity from the contract
   */
   function removeLiquidity(
      uint256 _acceptedTokenAmount,
      uint256 _usdtAmount
   ) external onlyOwner{
      require(acceptedToken.balanceOf(address(this)) >= _acceptedTokenAmount, "insufficient accepted token balance");
      require(usdtToken.balanceOf(address(this)) >= _usdtAmount, "insifficient Usdt balance");

      if (_acceptedTokenAmount > 0) {
         acceptedToken.safeTransfer(owner, _acceptedTokenAmount);
      }
      if (_usdtAmount > 0) {
         usdtToken.safeTransfer(owner, _usdtAmount);
      }
      emit LiquidityRemoved(_acceptedTokenAmount, _usdtAmount);
   }

   /*
   *@notice Toggles the contract's paused state in case of an emergency.
   */
   function setPaused(bool _status) external onlyOwner {
      isPaused = _status;
      emit Paused(_status);
   }
}