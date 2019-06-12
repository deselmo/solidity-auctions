pragma solidity >=0.5.0 <0.6.0;

contract Auction {
  uint constant internal gracePeriod = 4500; // ~ 5 minuts
  uint private gracePeriodEndBlock;

  address payable public seller;

  constructor() internal {
    seller = msg.sender;
    gracePeriodEndBlock = block.number + gracePeriod;
  }

  function bid() public payable
    isAuctionActive
    isNotSeller
  {}

  function activated() public view returns(bool) {
    return block.number > gracePeriodEndBlock;
  }

  modifier isAuctionActive() {
    require(activated(), 'The grace period has not yet elapsed');
    _;
  }

  modifier isNotSeller() {
    require(msg.sender != seller, 'The seller cannot bid');
    _;
  }
}