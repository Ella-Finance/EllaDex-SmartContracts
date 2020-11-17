pragma solidity >=0.4.0 <0.7.0;
import "./EllaExchange.sol";
import "./IEllaExchangeService.sol";



contract EllaExchangeService is IEllaExchangeService {
    mapping(bytes => bool) isListed;
     struct Requests{
      address payable creator;
      uint requestType;
      uint changeTo;
      string reason;
      uint positiveVote;
      uint negativeVote;
      uint powerUsed;
      
      bool stale;
      uint votingPeriod;
    }
      struct Votters{
      address payable voter;
    }
     Votters[] voters;
    
    Requests[] requests;
    mapping(uint => Requests[]) listOfrequests;
    mapping(uint => mapping(address => uint)) requestPower;
    mapping(uint => bool) activeRequest;
    uint private requestCreationPower;
    mapping(uint => mapping(address => bool)) manageRequestVoters;
    mapping(uint => Votters[]) activeRequestVoters;
    uint trading_fee;
    address payable trading_fee_address;
    uint system_cut;
    IERC20 EGR;
     /**
     * Construct a new exchange Service
     * @param _egr address of the EGR ERC20 token
     */
constructor(address _egr, uint _initial_fees, address payable _trading_fee_address, uint _system_cut, uint _requestCreationPower) public {
    EGR = IERC20(_egr);
    trading_fee = _initial_fees;
    trading_fee_address = _trading_fee_address;
    system_cut = _system_cut;
    requestCreationPower = _requestCreationPower;
    }


function createExchange(
        address _marketAddress, 
        address _tokenAddress, 
        bool _isEthereum,
        address _priceAddress,
        string memory _market
        
    ) public override returns (address _exchange) {
      bytes memory market = bytes(_toLower(_market));
      require(!isListed[market], "Market already listed");
      EllaExchange exchange = new EllaExchange(address(_marketAddress), address(_tokenAddress), _isEthereum, address(_priceAddress), address(this));
      _exchange = address(exchange);
      isListed[market] = true;
      emit ExchangeCreated(_exchange, _market, _marketAddress, _tokenAddress);
    }
    
    
function getFees() public view returns(uint) {
    return trading_fee;
}

function getSystemCut() public view returns(uint) {
    return system_cut;
}

function getFeesAddress() public view returns(address) {
    return trading_fee_address;
}



/// Request
function createRequest(uint _requestType, uint _changeTo, string memory _reason) public override{
    require(_requestType == 0 || _requestType == 1 || _requestType == 2,  "Invalid request type!");
    require(!activeRequest[_requestType], "Another request is still active");
   
    require(EGR.allowance(msg.sender, address(this)) >= requestCreationPower, "Insufficient EGR allowance for vote!");
    EGR.transferFrom(msg.sender, address(this), requestCreationPower);
    Requests memory _request = Requests({
      creator: msg.sender,
      requestType: _requestType,
      changeTo: _changeTo,
      reason: _reason,
      positiveVote: 0,
      negativeVote: 0,
      powerUsed: requestCreationPower,
      
      stale: false,
      votingPeriod: block.timestamp.add(4 days)
    });
    
    requests.push(_request);
    uint256 newRequestID = requests.length - 1;
     Requests memory request = requests[newRequestID];
    emit RequestCreated(
      request.creator,
      request.requestType,
      request.changeTo,
      request.reason,
      request.positiveVote,
      request.negativeVote,
      request.powerUsed,
      request.stale,
      request.votingPeriod,
      newRequestID
      );
}


function governanceVote(uint _requestType, uint _requestID, uint _votePower, bool _accept) public override{
    Requests storage request = requests[_requestID];
    require(request.votingPeriod >= block.timestamp, "Voting period ended");
    require(_votePower > 0, "Power must be greater than zero!");
    require(_requestType == 0 || _requestType == 1 || _requestType == 2,  "Invalid request type!");
   
    require(EGR.allowance(msg.sender, address(this)) >= _votePower, "Insufficient EGR allowance for vote!");
    EGR.transferFrom(msg.sender, address(this), _votePower);
    requestPower[_requestType][msg.sender] = requestPower[_requestType][msg.sender].add(_votePower);
     
     
       if(_accept){
            request.positiveVote = request.positiveVote.add(_votePower);
        }else{
            request.negativeVote = request.negativeVote.add(_votePower);  
        }
      
           
            if(manageRequestVoters[_requestID][msg.sender] == false){
                manageRequestVoters[_requestID][msg.sender] = true;
                activeRequestVoters[_requestID].push(Votters(msg.sender));
            }
       
          
    
    emit VotedForRequest(msg.sender, _requestID, request.positiveVote, request.negativeVote, _accept);
    
}

function validateRequest(uint _requestID) public override{
    Requests storage request = requests[_requestID];
    //require(block.timestamp >= request.votingPeriod, "Voting period still active");
    require(!request.stale, "This has already been validated");
   
   
    if(request.requestType == 0){
        if(request.positiveVote >= request.negativeVote){
            trading_fee = request.changeTo;
           
            
        }
        
    }else if(request.requestType == 1){
        if(request.positiveVote >= request.negativeVote){
            requestCreationPower = request.changeTo;
           
            
            
        }
        
    }else if(request.requestType == 2){
        if(request.positiveVote >= request.negativeVote){
            system_cut = request.changeTo;
            
            
            
        }
        
    }
    else if(request.requestType == 3){
        if(request.positiveVote >= request.negativeVote){
            trading_fee_address = request.creator;
            
            
            
        }
        
    }
   
    request.stale = true;
    
   
    
    for (uint256 i = 0; i < activeRequestVoters[_requestID].length; i++) {
           address voterAddress = activeRequestVoters[_requestID][i].voter;
           uint amount = requestPower[request.requestType][voterAddress];
           require(EGR.transfer(voterAddress, amount), "Fail to refund voter");
           requestPower[request.requestType][voterAddress] = 0;
           emit Refunded(amount, voterAddress, _requestID, now);
    }
    
     require(EGR.transfer(request.creator, request.powerUsed), "Fail to transfer fund");
    emit ApproveRequest(_requestID, request.positiveVote >= request.negativeVote, msg.sender);
}


function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
    

 }