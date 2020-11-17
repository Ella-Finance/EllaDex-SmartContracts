pragma solidity >= 0.4.0 < 0.7.0;
import './SafeMath.sol';
import './IERC20.sol';
// Libraries
import './SafeDecimalMath.sol';



interface IEllaExchange {
    using SafeMath for uint;
    using SafeDecimalMath for uint;
    event Saved(uint _amount, bool _isMarket, address _contract,  uint _time, address _owner, uint _duration);
    event Withdrew(uint _amount, address _owner, address _to, address _contract, bool _isMarket, uint _time);
    event Bought(uint _price, uint _amount, uint _value, address _market, bool isMarket, uint time);
        event Rewarded(
        address provider, 
        uint share, 
        bool _isMarket, 
        uint time
        );
    event PriceFeedChange(address _newAddress, address _exchange);
    function save(uint _amount, bool _isMarket, uint _duration) external;
    function save1(bool _isMarket, uint _duration) payable external;
     
    function withdraw(uint _amount,  address _to, bool _isMarket) external;
    function withdraw1(address payable _to, uint _amount, bool _isMarket) external;
     
    function accountBalance(address _owner) external view returns (uint _market, uint _token, uint _ethers);
     
    
    function swap(uint _amount) external;
    function swapBase(uint _amount) external;
    function swapBase2(uint _amount) external;
    function swap1(uint _amount) external;
    function swapBase1() payable external;
    function swap2() payable external;
    
}
