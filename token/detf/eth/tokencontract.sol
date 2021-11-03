// EDTF Token for Ethereum Decentralized Funds
// Used as incentive for balancing passively managed decentralized Exchange Traded Funds
// In order to keep equilibrium of the traded funds fund contributors can be rewarded with EDTF tokens
// A 0.18% fee is sent to the Developer account for interacting with the contract
// EDTF Token holders can burn the token in exchange for ETH
// For more information check edtftoken.com

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BassketToken is ERC20, Ownable, ERC20Burnable {
    using SafeMath for uint256;
    uint256 internal incomingValue;
    uint256 internal toTokenDev; 
    uint256 internal toMint; 
    uint256 public minted;
    uint256 internal convertedAmount; 
    uint256 public availableForBuyback;
    uint256 internal buybackValue; 
    uint256 internal redeemAble;
    uint256 internal baseEchange;
    uint256 internal pctAv;
    uint256 public currentRate;
    uint256 public fee;
    uint256 internal mintedAmount; 
    
    event Minted(address indexed _from, uint256 _minted, uint256 _fee, uint256 _netcost);
    event Redeemed(address indexed _from, uint256 _redeemedBaseAmount, uint256 _fee, uint256 _redeemedAmount);
    event ToRedeem(address indexed _from, uint256 _redeemedBaseAmount, uint256 _fee, uint256 _redeemedAmount);
   
    struct developerFeeDetails { 
        uint256 fee;
        string name;
        uint decimals;
    }
    
    developerFeeDetails public developerFee;
    
    function setDevFees() internal {
      developerFee = developerFeeDetails(18, 'Developer Fee Details', 4);
    }
    
    constructor() ERC20("Ethereum Decentralized Traded Fund Token", "EDTF") {
         setDevFees();
         _mint(payable(owner()), 1);
         minted = 1;
         baseEchange = 10**12;
         currentRate = 10**12;
    }

    function mint(address to, uint256 amount) internal returns(uint256 mintedval) {
        
        convertedAmount = amount.mul(1000000000000000).div(getCurrentPrice());
        _mint(to, convertedAmount);
        availableForBuyback = availableForBuyback.add(amount);
        mintedval = convertedAmount;
        return mintedval;
    }
    
    
    function redeem(uint256 pct) public payable returns(uint256 ethAmount) {
        redeemAble = balanceOf(msg.sender).mul(pct).div(100);
        pctAv = redeemAble.mul(10**12).div(this.totalSupply());
        ethAmount = (availableForBuyback.mul(pctAv).div(10**12));
        toTokenDev = developerFee.fee.mul(ethAmount).div(10**developerFee.decimals);
        ethAmount = ethAmount - toTokenDev;
        availableForBuyback = availableForBuyback.sub(ethAmount + toTokenDev);
        bool sent = payable(msg.sender).send(ethAmount);
        require(sent, "Failed to send Ether" );
        bool feesent = payable(owner()).send(toTokenDev);
        require(feesent, "Failed to send <fee" );
        burnFrom(msg.sender, redeemAble);
        emit Redeemed(msg.sender, ethAmount, toTokenDev, redeemAble);
        return ethAmount;
        
    }
    
    //price to mint the token rises linearly with the amount of minted tokens
    function getCurrentPrice() public view returns(uint256 price) {
        price = baseEchange + minted.div(10**13);
        return price;
    }
    
    
    function mint() public payable returns(uint256 MintedAmount){
        incomingValue = msg.value;
        toTokenDev = developerFee.fee.mul(msg.value).div(10**developerFee.decimals);
        toMint = incomingValue.sub(toTokenDev);
        payable(owner()).transfer(toTokenDev);
        mintedAmount = mint(msg.sender, toMint);
        minted = minted.add(mintedAmount);
        MintedAmount = mintedAmount;
        emit Minted(msg.sender, mintedAmount, toTokenDev, toMint);
        return MintedAmount;
    }
    
    function mintToContract(address contractAddress) public payable returns(uint256 MintedAmount){
        incomingValue = msg.value;
        toTokenDev = developerFee.fee.mul(msg.value).div(10**developerFee.decimals);
        toMint = incomingValue.sub(toTokenDev);
        payable(owner()).transfer(toTokenDev);
        mintedAmount = mint(contractAddress, toMint);
        minted = minted.add(mintedAmount);
        MintedAmount = mintedAmount;
        emit Minted(contractAddress, mintedAmount, toTokenDev, toMint);
        return MintedAmount;
    }
    
}
