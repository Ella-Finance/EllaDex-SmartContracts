pragma solidity >= 0.4.0 < 0.7.0;
import './SafeMath.sol';
import './IERC20.sol';
import './EllaExchange.sol';



interface IEllaExchangeService {
    using SafeMath for uint;
      event RequestCreated(
      address _creator,
      uint _requestType,
      uint _changeTo,
      string _reason,
      uint _positiveVote,
      uint _negativeVote,
      uint _powerUsed,
      bool _stale,
      uint _votingPeriod,
      uint _requestID
      );
    event ExchangeCreated(address _exchange, string _market, address _base_address, address _token_address );
    function createRequest(uint _requestType, uint _changeTo, string calldata _reason) external;
    function createExchange(address _marketAddress, address _tokenAddress, bool _isEthereum, address _priceAddress, string calldata _market) external returns (address _exchange);
      event VotedForRequest(
        address _voter,
        uint _requestID,
        uint _positiveVote,
        uint _negativeVote,
        bool _accept
    );
    
      event Refunded(uint amount, address voterAddress, uint _loanID, uint time);
      event ApproveRequest(uint _requestID, bool _state, address _initiator);  
      function validateRequest(uint _requestID) external;
      function governanceVote(uint _requestType, uint _requestID, uint _votePower, bool _accept) external;
    
}
