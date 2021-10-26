
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import "@chainlink/contracts/src/v0.8/Denominations.sol";

contract DETFTEMPLATE is ERC20, Ownable, ERC20Burnable {
    
    bool public runningState;
    using SafeMath for uint256;
    enum tokenState { active, inactive, purging  }
    enum tokenType { native, onchain, fee  }
    
    struct holding { 
        uint256 _marketCap; 
        uint256 _holdingBalance; 
        uint256 _holdingValue;
        uint256 _weight;
        uint256 _targetWeight;
        int256 _lastQuote;
        uint _quoteDecimals;
        address _tokenAddress;
        address _chainlinkAddress;
        tokenState _tokenState;
        tokenType _tokenType;
    }
    
    struct holdingsymbol {
        string _symbol;
        uint _decimals;
    }
    
    struct feeDetail { 
        uint256 feeHoldingPct;
        uint feeContractId;
        uint256 feeRewardPct;
        uint256 feeCostPct;
    }
    
    struct runVar { 
        uint256 incomingValue;
        uint256 totalMarketCap;
        uint256 tmpMarketCap;
        uint256 toFeeHoldings;
        uint256 totalNav;
        uint256 tmpNav;
        uint256 nativeQuote;
        uint256 Minted;
        uint256 depositAmount;
    }
    
    feeDetail feeDetails;
    runVar public runVars;
    mintFee mintfee_instance;
    uint256 public witheldFee;
    holding[] public holdings;
    holdingsymbol[] public holdingsymbols;

    
    function initHoldings() internal {
      holdings.push(holding(118061547, 0, 0, 0, 0, 0, 8, 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 0x9326BFA02ADD2366b30bacB125260Af641031331, tokenState.active, tokenType.native ));
      holdingsymbols.push(holdingsymbol('ETH', 18));     
      holdings.push(holding(18853125 , 0, 0, 0, 0, 0, 8, 0x9b6Ff80Ff8348852d5281de45E66B7ED36E7B8a9, 0xDA5904BdBfB4EF12a3955aEcA103F51dc87c7C39, tokenState.active, tokenType.onchain ));
      holdingsymbols.push(holdingsymbol('UNI', 18));  
      holdings.push(holding(188531250 , 0, 0, 0, 0, 0, 18, 0x2A75EAC8B580d0DB0C6bFDabD6672C97ad2b2559, 0x9326BFA02ADD2366b30bacB125260Af641031331, tokenState.active, tokenType.fee ));
      holdingsymbols.push(holdingsymbol('FEE', 18));  
      feeDetails.feeContractId = 2;
      witheldFee = 0;
    }
    
    
    constructor() ERC20("Ethereum Decentralised Exchange Traded Fund - Contract Template", "XTFT") {
        runningState = true;
        initHoldings();
        initInterface();
        feeDetails.feeHoldingPct = 3;
        feeDetails.feeRewardPct = 1;
        feeDetails.feeCostPct = 1;
        updatePrices();
        runVars.totalMarketCap = 1;
    }
    
    function initInterface () internal {
        mintfee_instance = mintFee(holdings[feeDetails.feeContractId]._tokenAddress);
    }
    
    function calcTotalCapUSDT() public view returns (uint256 totalCapUSDT){
        totalCapUSDT = 0;
        for (uint i=0; i<holdings.length; i++) {
        if (holdings[i]._tokenType != tokenType.fee ) {
            totalCapUSDT = totalCapUSDT + (holdings[i]._marketCap.mul(uint256(holdings[i]._lastQuote)));
         } 
        }
        
      
        return(totalCapUSDT);
        
        
    }
    
    function updatePrices() public {
       runVars.tmpMarketCap = 0;
       runVars.tmpNav = 0;
        for (uint i=0; i<holdings.length; i++) {
            if (holdings[i]._tokenType == tokenType.native ) {
            holdings[i]._holdingBalance = address(this).balance;
            setHolding(i);
            
        
            }
            if (holdings[i]._tokenType == tokenType.onchain ) {
            holdings[i]._holdingBalance = checkBalance(holdings[i]._tokenAddress, address(this));
            setHolding(i);
            
            }
            if (holdings[i]._tokenType == tokenType.fee ) {
            holdings[i]._lastQuote = getPriceFromFeeToken(holdings[i]._tokenAddress);
            holdings[i]._holdingBalance = checkBalance(holdings[i]._tokenAddress, address(this));
            holdings[i]._holdingValue = ((holdings[i]._holdingBalance.mul(uint256(holdings[i]._lastQuote)).div(10 ** 18)).mul(uint256(holdings[0]._lastQuote))).div(10 ** 21);
            runVars.tmpNav = runVars.tmpNav + holdings[i]._holdingValue;
            feeDetails.feeContractId = i;
            }
        }
        runVars.totalMarketCap = runVars.tmpMarketCap;
        runVars.totalNav = runVars.tmpNav;
      
    }
    
    function setHolding(uint i) internal {
        holdings[i]._lastQuote = getPrice(holdings[i]._chainlinkAddress);
        holdings[i]._holdingValue = holdings[i]._holdingBalance.mul(uint256(holdings[i]._lastQuote)).div(10 ** 18);
        runVars.tmpMarketCap = runVars.tmpMarketCap + (holdings[i]._marketCap.mul(uint256(holdings[i]._lastQuote)));
        runVars.tmpNav = runVars.tmpNav + holdings[i]._holdingValue;
        
    }
    
          
    
    function checkBalance(address token, address holder) public view returns(uint256) {

        ERC20 t = ERC20(token);
        return (t.balanceOf(holder));
    }
    
    function getPriceFromFeeToken(address feeContractAddress) public view returns (int256 feePrice) {
       BassketToken feecontract = BassketToken(feeContractAddress);
       feePrice = feecontract.getCurrentPrice();
       feePrice = int256(feePrice);
       return feePrice;
        
    }
    
    
   function depositNative() public payable {
       
        runVars.incomingValue = msg.value;
        runVars.toFeeHoldings = (feeDetails.feeHoldingPct * msg.value) / 100;
        mintfee_instance.mintToContract{gas:3000000, value:runVars.toFeeHoldings}(address(this));
        witheldFee = witheldFee + runVars.toFeeHoldings;
        updatePrices();
        holdings[0]._weight = (holdings[0]._holdingValue.mul(10000)).div(runVars.totalNav);
        holdings[2]._weight = (holdings[2]._holdingValue.mul(10000)).div(runVars.totalNav);
        holdings[2]._targetWeight =  300;
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


interface mintFee {
    function mintToContract (address contractAddress) external payable;
}

abstract contract BassketToken {
    function getCurrentPrice() public view virtual returns(int256);
}
