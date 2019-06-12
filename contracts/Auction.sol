pragma solidity >=0.5.0 <0.6.0;

contract Auction {
  uint internal gracePeriod = 4500; // ~ 5 minuts
  uint internal creationBlock;

  address payable public seller;

  constructor() internal {
    seller = msg.sender;
    creationBlock = block.number;
  }

  function gracePeriodEndBlock() internal view returns(uint) {
    return creationBlock + gracePeriod;
  }

  function bid() public payable
    isAuctionActive
    isNotSeller
  {}

  function activated() public view returns(bool) {
    return block.number > gracePeriodEndBlock();
  }

  modifier isAuctionActive() {
    require(activated(), 'The grace period has not yet elapsed');
    _;
  }

  modifier isNotAuctionActive() {
    require(!activated(), 'The grace period is already elapsed');
    _;
  }

  modifier isNotSeller() {
    require(msg.sender != seller, 'The seller cannot bid');
    _;
  }

  function forceGracePeriodTermination() external isNotAuctionActive {
    gracePeriod = block.number - creationBlock;
  }
}