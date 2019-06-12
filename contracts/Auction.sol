pragma solidity >=0.5.0 <0.6.0;

contract Auction {
  uint internal gracePhaseLength = 4500; // ~ 5 minuts
  uint internal creationBlock;

  address payable public seller;

  constructor() internal {
    seller = msg.sender;
    creationBlock = block.number;
  }


  modifier isNotSeller() {
    require(msg.sender != seller, 'The seller cannot bid');
    _;
  }


  function gracePhaseStartBlock() internal view returns(uint) {
    return creationBlock + 1;
  }

  function gracePhaseEndBlock() internal view returns(uint) {
    return gracePhaseStartBlock() + gracePhaseLength;
  }

  function inGracePhase() public view returns(bool) {
    return block.number >= gracePhaseStartBlock() &&
           block.number <= gracePhaseEndBlock();
  }

  modifier isInGracePhase() {
    require(inGracePhase(),
           'It is necessary to be in grace phase to call this operation');
    _;
  }

  function forceGracePhaseTermination() external isInGracePhase {
    gracePhaseLength = block.number - gracePhaseStartBlock();
  }


  function auctionTerminated() public view returns(bool);

  modifier isAuctionTerminated() {
    require(auctionTerminated(),
            'The auction must be completed to call this operation');
    _;
  }
}