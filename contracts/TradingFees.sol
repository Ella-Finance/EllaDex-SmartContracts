pragma solidity >=0.6.0;
interface FEES {
      function getFees() external view returns (uint);
      function getSystemCut() external view returns (uint);
      function getFeesAddress() external view returns (address payable);
}