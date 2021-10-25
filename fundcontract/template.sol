pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import "@chainlink/contracts/src/v0.8/Denominations.sol";

contract DETFTEMPLATE is ERC20, Ownable, ERC20Burnable {
    
    bool public runningState;
    
    enum tokenState { active, inactive, purging  }
    enum tokenType { native, onchain, fee  }
    
    struct holding { 
        string _symbol;
        uint _decimals;
        uint256 _marketCap; 
        uint256 _holdingBalance; 
        uint256 _holdingValue;
        uint256 _overWeight;
        uint256 _underWeight;
        int256 _lastQuote;
        uint _quoteDecimals;
        address _tokenAddress;
        address _chainlinkAddress;
        tokenState _tokenState;
        tokenType _tokenType;
    }
    
    uint256 feeHoldingPct;
    uint256 feeRewardPct;
    uint256 feeCostPct;
    uint256 totalMarketCap;
    uint256 tmpMarketCap;
    uint256 nativeQuote;
    holding[] public holdings;

    
    function initHoldings() internal {
      holdings.push(holding('ETH', 18, 118061547, 0, 0, 0, 0, 0, 8, 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 0x9326BFA02ADD2366b30bacB125260Af641031331, tokenState.active, tokenType.native ));
      holdings.push(holding('UNI', 18, 18853125 , 0, 0, 0, 0, 0, 8, 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 0xDA5904BdBfB4EF12a3955aEcA103F51dc87c7C39, tokenState.active, tokenType.onchain ));
      holdings.push(holding('DETF', 18, 188531250 , 0, 0, 0, 0, 0, 18, 0x14985b4a5a01BCdE918787AEf7C6e3b9570f5176, 0x9326BFA02ADD2366b30bacB125260Af641031331, tokenState.active, tokenType.fee ));
    }
    
    
    constructor() ERC20("Ethereum Decentralised Exchange Traded Fund - Contract Template", "XTFT") {
        runningState = true;
        initHoldings();
        feeHoldingPct = 3;
        feeRewardPct = 1;
        feeCostPct = 1;
        updatePrices();
    }
    
    function updatePrices() internal {
       tmpMarketCap = 0;
        for (uint i=0; i<holdings.length; i++) {
            if (holdings[i]._tokenType == tokenType.native ) {
            holdings[i]._lastQuote = getPrice(holdings[i]._chainlinkAddress);
            tmpMarketCap = tmpMarketCap + holdings[i]._marketCap;
            holdings[i]._holdingBalance = address(this).balance;
            holdings[i]._holdingValue = holdings[i]._holdingBalance * uint256(holdings[i]._lastQuote);
            nativeQuote = uint256(holdings[i]._lastQuote);
            }
            if (holdings[i]._tokenType == tokenType.onchain ) {
            holdings[i]._lastQuote = getPrice(holdings[i]._chainlinkAddress);
            tmpMarketCap = tmpMarketCap + holdings[i]._marketCap;
            holdings[i]._holdingBalance = checkBalance(holdings[i]._tokenAddress, address(this));
            holdings[i]._holdingValue = holdings[i]._holdingBalance * uint256(holdings[i]._lastQuote);
            }
            if (holdings[i]._tokenType == tokenType.fee ) {
            holdings[i]._lastQuote = getPriceFromFeeToken(holdings[i]._tokenAddress);
            holdings[i]._holdingBalance = checkBalance(holdings[i]._tokenAddress, address(this));
            holdings[i]._holdingValue = holdings[i]._holdingBalance * uint256(holdings[i]._lastQuote) * nativeQuote;
            }
        }
        totalMarketCap = tmpMarketCap;
        tmpMarketCap = 0;
    }
    
    function updateHoldingBalancing() internal {
       if (address(this).balance > 0 ) {
          
       } 
    }
    
    function checkBalance(address token, address holder) public view returns(uint) {
        IERC20 token = IERC20(token);
        return token.balanceOf(holder);
    }
    
    function getPriceFromFeeToken(address feeContractAddress) public view returns (int256 feePrice) {
       BassketToken feecontract = BassketToken(feeContractAddress);
       feePrice = feecontract.getCurrentPrice();
       feePrice = int256(feePrice);
       return feePrice;
        
    }
    
    function getPrice(address priceFeedAddress) public view returns (int256 priceQuote) {
        try AggregatorV3Interface(priceFeedAddress).latestRoundData() returns (
            uint80,         // roundID
            int256 price,   // price
            uint256,        // startedAt
            uint256,        // timestamp
            uint80          // answeredInRound
        ) {
            return price;
        } catch Error(string memory) {            
            // handle failure here:
            // revert, call propietary fallback oracle, fetch from another 3rd-party oracle, etc.
            bool oracleOnline;
            int256 price;
            oracleOnline = true;
            price = 0;
            return price;
        }
    }
}  

abstract contract BassketToken {
    function getCurrentPrice() public view virtual returns(int256);
}
