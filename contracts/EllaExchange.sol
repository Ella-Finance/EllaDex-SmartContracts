pragma solidity >= 0.4.0 < 0.7.0;
import './IEllaExchange.sol';
import './IPriceConsumer.sol';
import './TradingFees.sol';


contract EllaExchange is IEllaExchange {
   IERC20 MarketAddress;
   IERC20 TokenAddress;
   FEES  TradingFees;
   bool private isEthereum;
   mapping (bool => mapping(address => bool)) alreadyAProvider;
    struct Providers{
      address payable provider;
    }
    
   Providers[] providers;
   mapping(bool => Providers[]) listOfProviders;
   
   mapping(bool => mapping(address => uint)) savings;
   mapping(address => uint) etherSavings;
   mapping(bool => uint) pool;
   uint etherpool;
   address secretary;
   uint baseFees_generated;
   uint fees_generated;
   
   mapping(address => mapping(bool => uint)) userWithdrawalDate;
   mapping(address => mapping(bool => uint)) withdrawalDate;
   AggregatorV3Interface internal priceFeed;
    constructor(address _marketAddress, address _tokenAddress, bool _isEthereum,  address _priceAddress, address _fees) public {
     MarketAddress = IERC20(_marketAddress);  
     TokenAddress  = IERC20(_tokenAddress);
     TradingFees = FEES(_fees);
     isEthereum = _isEthereum;
     priceFeed = AggregatorV3Interface(_priceAddress);
     secretary = msg.sender;
    }

    function description() external view returns (string memory){
    return priceFeed.description();
    }
    
    function decimals() external view returns (uint8){
     return priceFeed.decimals();
    }
    
  
  function version() external view returns (uint256){
    return priceFeed.version();
  }
  
  function tokenPrice() public view returns(uint){
        (
        uint80 roundId, 
        int256 answer, 
        uint256 startedAt, 
        uint256 updatedAt, 
        uint80 answeredInRound
      ) = priceFeed.latestRoundData();
     uint multiplier = 10**uint(SafeMath.sub(18, priceFeed.decimals()));
     uint _price = uint(uint(answer).mul(multiplier));
     return _price;
  }
  
     /**
     * Restrict access to Secretary role
     */
    modifier onlySecretary() {
        require(secretary == msg.sender, "Address is not Secretary of this exchange!");
        _;
    }
    
    
    function changePriceFeedAddress(address _new_address) public onlySecretary {
       priceFeed = AggregatorV3Interface(_new_address);
       
       emit PriceFeedChange(_new_address, address(this));
    }
    
    
    function save(uint _amount, bool _isMarket, uint _duration) public override{
        require(_amount > 0, "Invalid amount");
        require(_duration > 0, "Invalid duration");
        require(setDuration(_duration, _isMarket) > 0, "Invalid duration");
        IERC20 iERC20 = (_isMarket ? MarketAddress : TokenAddress);
        require(iERC20.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance!");
        iERC20.transferFrom(msg.sender, address(this), _amount);
        savings[_isMarket][msg.sender] = savings[_isMarket][msg.sender].add(_amount);
        pool[_isMarket] = pool[_isMarket].add(_amount);
          if(alreadyAProvider[_isMarket][msg.sender] == false){
              alreadyAProvider[_isMarket][msg.sender] = true;
                listOfProviders[_isMarket].push(Providers(msg.sender));
            }
        emit Saved(_amount, _isMarket, address(this), now, msg.sender, setDuration(_duration, _isMarket));
    }
    
    function withdraw(uint _percentage, address _to, bool _isMarket) public override{
        require(_percentage > 0, "Invalid amount");
        require(isDue(_isMarket, msg.sender), "Lock period is not over yet!");
        IERC20 iERC20 = (_isMarket ? MarketAddress : TokenAddress);
        uint _withdrawable = withdrawable(_percentage, msg.sender, _isMarket, false);
        uint _deduct = _percentage.multiplyDecimalRound(savings[_isMarket][msg.sender]);
        savings[_isMarket][msg.sender] = _deduct >= savings[_isMarket][msg.sender] ? 0 : savings[_isMarket][msg.sender].sub(_deduct);
        pool[_isMarket] = _withdrawable >= pool[_isMarket] ? 0 : pool[_isMarket].sub(_withdrawable);
        require(iERC20.transfer(_to, _withdrawable), "Withdrawal faild");
        emit Withdrew(_withdrawable,msg.sender, _to, address(this),_isMarket, now);
    }
    
    function withdrawable(uint _percentage, address _user, bool _isMarket, bool _isForEther) public view returns(uint){
        uint pool_balance = _isForEther ? etherpool : pool[_isMarket];
        uint contract_balance = _isForEther ? address(this).balance : (_isMarket ? MarketAddress.balanceOf(address(this)) : TokenAddress.balanceOf(address(this)));
        uint get_user_pool_share = _isForEther ? etherSavings[_user].divideDecimalRound(pool_balance) : savings[_isMarket][_user].divideDecimalRound(pool_balance);
        uint user_due = get_user_pool_share.multiplyDecimalRound(contract_balance);
        uint _widthdrawable = _percentage.multiplyDecimalRound(user_due);
        
        return _widthdrawable;
    }
    
    function save1(bool _isMarket, uint _duration) payable public override{
        require(msg.value > 0, "Invalid amount");
        require(_duration > 0, "Invalid duration");
        require(setDuration(_duration, _isMarket) > 0, "Invalid duration");
        require(isEthereum, "Can't save Ethereum in this contract");
        etherSavings[msg.sender] = etherSavings[msg.sender].add(msg.value);
        etherpool = etherpool.add(msg.value);
         if(alreadyAProvider[_isMarket][msg.sender] == false){
              alreadyAProvider[_isMarket][msg.sender] = true;
                listOfProviders[_isMarket].push(Providers(msg.sender));
            }
        emit Saved(msg.value, _isMarket, address(this), now, msg.sender, setDuration(_duration, _isMarket));
    }
    
    function withdraw1(address payable _to, uint _percentage, bool _isMarket) public override{
        require(_percentage > 0, "Invalid amount");
        require(isDue(_isMarket, msg.sender), "Lock period is not over yet!");
        uint _withdrawable = withdrawable(_percentage, msg.sender, _isMarket, true);
        _to.transfer(_withdrawable);
        uint _deduct = _percentage.multiplyDecimalRound(etherSavings[msg.sender]);
        etherSavings[msg.sender] = _deduct >= etherSavings[msg.sender] ? 0 : etherSavings[msg.sender].sub(_deduct);
        etherpool = _withdrawable >= etherpool ? 0 : etherpool.sub(_withdrawable);
        emit Withdrew(_withdrawable,msg.sender, _to, address(this), _isMarket, now);
    }
    
    function accountBalance(address _owner) public override view returns (uint _market, uint _token, uint _ethers){
        return(savings[true][_owner], savings[false][_owner], etherSavings[_owner]);
    }
    
    
    
    function swapBase(uint _amount) public override{
        require(!isEthereum, "Can't transact!");
        require(_amount > 0, "Zero value provided!");
        require(MarketAddress.allowance(msg.sender, address(this)) >= _amount, "Non-sufficient funds");
        require(MarketAddress.transferFrom(msg.sender, address(this), _amount), "Fail to tranfer fund");
        uint _price = tokenPrice();
        uint _amountDue = _amount.divideDecimal(_price);
        uint _finalAmount = _amountDue.multiplyDecimal(10 ** 18);
        require(TokenAddress.balanceOf(address(this)) >= _finalAmount, "No fund to execute the trade");
        uint fee = TradingFees.getFees().multiplyDecimal(_finalAmount);
        uint systemCut = TradingFees.getSystemCut().multiplyDecimal(fee);
        fees_generated = fees_generated.add(fee.sub(systemCut));
        require(TokenAddress.transfer(msg.sender, _finalAmount.sub(fee)), "Fail to tranfer fund");
        require(TokenAddress.transfer(TradingFees.getFeesAddress(), systemCut), "Fail to tranfer fund");
      
        emit Bought(_price, _finalAmount, _amount, address(this), true, now);
       
    }
    
    function swapBase2(uint _amount) public override{
        require(isEthereum, "Can not transact!");
        require(_amount > 0, "Zero value provided!");
        require(MarketAddress.allowance(msg.sender, address(this)) >= _amount, "Non-sufficient funds");
        require(MarketAddress.transferFrom(msg.sender, address(this), _amount), "Fail to tranfer fund");
        address payable _reciever = msg.sender;
        address payable _reciever2 = TradingFees.getFeesAddress();
        uint _price = tokenPrice();
        uint _amountDue = _amount.divideDecimal(_price);
        uint _finalAmount = _amountDue.multiplyDecimal(10 ** 18);
        
        require(address(this).balance >= _finalAmount, "No fund to execute the trade");
        uint fee = TradingFees.getFees().multiplyDecimal(_finalAmount);
        uint systemCut = TradingFees.getSystemCut().multiplyDecimal(fee);
        fees_generated = fees_generated.add(fee.sub(systemCut));
        
        _reciever.transfer(_finalAmount.sub(fee));
        _reciever2.transfer(systemCut);
        emit Bought(_price, _finalAmount, _amount, address(this), true, now);
       
    }
    
    
     // swap base(eth) for token
     function swapBase1() payable public override{
        require(isEthereum, "Can't transact!");
        require(msg.value > 0, "Zero value provided!");
        uint _price = tokenPrice();
        uint _amount = msg.value;
        uint _amountDue = _amount.divideDecimal(_price);
        uint _finalAmount = _amountDue.multiplyDecimal(10 ** 18);
        require(TokenAddress.balanceOf(address(this)) >= _finalAmount, "No fund to execute the trade");
        uint fee = TradingFees.getFees().multiplyDecimal(_finalAmount);
        uint systemCut = TradingFees.getSystemCut().multiplyDecimal(fee);
        fees_generated = fees_generated.add(fee.sub(systemCut));
        require(TokenAddress.transfer(msg.sender, _finalAmount.sub(fee)), "Fail to tranfer fund");
        require(TokenAddress.transfer(TradingFees.getFeesAddress(), systemCut), "Fail to tranfer fund");
        emit Bought(_price, _finalAmount, _amount, address(this), true, now);
        
    }
    
    // (swap your token to base)
    function swap(uint _amount) public override{
        require(!isEthereum, "Can't transact!");
        require(_amount > 0, "Zero value provided!");
        require(TokenAddress.allowance(msg.sender, address(this)) >= _amount, "Non-sufficient funds");
        require(TokenAddress.transferFrom(msg.sender, address(this), _amount), "Fail to tranfer fund");
        uint _price = tokenPrice();
        uint _amountDue = _amount.multiplyDecimal(_price);
        uint _finalAmount = _amountDue.divideDecimal(10 ** 18);
        require(MarketAddress.balanceOf(address(this)) >= _finalAmount, "No fund to execute the trade");
        uint fee = TradingFees.getFees().multiplyDecimal(_finalAmount);
        uint systemCut = TradingFees.getSystemCut().multiplyDecimal(fee);
        baseFees_generated = baseFees_generated.add(fee.sub(systemCut));
        require(MarketAddress.transfer(msg.sender, _finalAmount.sub(fee)), "Fail to tranfer fund");
        require(MarketAddress.transfer(TradingFees.getFeesAddress(), systemCut), "Fail to tranfer fund");
        emit Bought(_price, _finalAmount, _amount, address(this), false, now);
    }
    
    //only call if eth is the base (swap your token to base)
    function swap1(uint _amount) public override{
        require(isEthereum, "Can't transact!");
        require(_amount > 0, "Zero value");
        require(TokenAddress.allowance(msg.sender, address(this)) >= _amount, "Non-sufficient funds");
        require(TokenAddress.transferFrom(msg.sender, address(this), _amount), "Fail to tranfer fund");
        address payable _reciever = msg.sender;
        address payable _reciever2 = TradingFees.getFeesAddress();
        uint _price = tokenPrice();
        uint _amountDue = _price.multiplyDecimal(_amount);
        uint _finalAmount = _amountDue.divideDecimal(10 ** 18);
        require(address(this).balance >= _finalAmount, "No fund to execute the trade");
        uint fee = TradingFees.getFees().multiplyDecimal(_finalAmount);
         uint systemCut = TradingFees.getSystemCut().multiplyDecimal(fee);
        baseFees_generated = baseFees_generated.add(fee.sub(systemCut));
        _reciever.transfer(_finalAmount.sub(fee));
        _reciever2.transfer(systemCut);
        emit Bought(_price, _finalAmount, _amount, address(this), false, now);
    }
    
      // When eth is the token
      function swap2() payable public override{
        require(isEthereum, "Can't transact!");
        require(msg.value > 0, "Zero value provided!");
        uint _price = tokenPrice();
        uint _amount = msg.value;
        uint _amountDue = _price.multiplyDecimal(_amount);
        uint _finalAmount = _amountDue.divideDecimal(10 ** 18);
        require(MarketAddress.balanceOf(address(this)) >= _finalAmount, "No fund to execute the trade");
        uint fee = TradingFees.getFees().multiplyDecimal(_finalAmount);
        uint systemCut = TradingFees.getSystemCut().multiplyDecimal(fee);
        baseFees_generated = baseFees_generated.add(fee.sub(systemCut));
        require(MarketAddress.transfer(msg.sender, _finalAmount.sub(fee)), "Fail to tranfer fund");
        require(MarketAddress.transfer(TradingFees.getFeesAddress(), systemCut), "Fail to tranfer fund");
        emit Bought(_price, _finalAmount, _amount, address(this), false, now);
      }
      
      function setDuration(uint _duration, bool _isbase) internal returns(uint){
          userWithdrawalDate[msg.sender][_isbase] == 0 ?  userWithdrawalDate[msg.sender][_isbase] = _duration : userWithdrawalDate[msg.sender][_isbase];
          if(_duration == 30){
              withdrawalDate[msg.sender][_isbase] = block.timestamp.add(30 days);
              return block.timestamp.add(30 days);
          }else if(_duration == 60){
              withdrawalDate[msg.sender][_isbase] = block.timestamp.add(60 days);
              return block.timestamp.add(60 days);
          }else if(_duration == 90){
              withdrawalDate[msg.sender][_isbase] = block.timestamp.add(90 days);
              return block.timestamp.add(90 days);
          }else if(_duration == 365){
              withdrawalDate[msg.sender][_isbase] = block.timestamp.add(365 days);
              return block.timestamp.add(365 days);
          }else if(_duration == 140000){
              withdrawalDate[msg.sender][_isbase] = block.timestamp.add(140000 days);
              return block.timestamp.add(140000 days);
          }else{
             return 0;
          }
      }
    function isDue(bool _isbase, address _user) public view returns (bool) {
        if (block.timestamp >= withdrawalDate[_user][_isbase])
            return true;
        else
            return false;
    }

    function shareFees(bool _isEth, bool _isMarket) public {
           uint feesShared;
           for (uint256 i = 0; i < listOfProviders[_isMarket].length; i++) {
            address payable _provider = listOfProviders[_isMarket][i].provider;
            uint userSavings =  _isEth ? etherSavings[_provider] : savings[_isMarket][_provider];
            uint _pool = _isEth ? etherpool : pool[_isMarket];
            uint total_fees_generated = _isMarket ? baseFees_generated : fees_generated;
            uint share = userSavings.divideDecimal(_pool);
            uint due = share.multiplyDecimal(total_fees_generated);
            feesShared = feesShared.add(due);
            require(total_fees_generated >= due, "No fees left for distribution");
            _isEth ? _provider.transfer(due) : _isMarket  ? require(MarketAddress.transfer(_provider, due), "Fail to tranfer fund") : require(TokenAddress.transfer(_provider, due), "Fail to tranfer fund"); 
           
           
            emit Rewarded(_provider, due, _isMarket, now);
           } 
           
            _isMarket ? baseFees_generated = baseFees_generated.sub(feesShared) : fees_generated = fees_generated.sub(feesShared);
        
    }
    
    
}