pragma solidity >=0.5.0 <0.6.0;

contract Auction {
  uint internal gracePhase = 4500; // ~ 5 minuts
  uint internal creationBlock;

  address payable public seller;

  constructor() internal {
    seller = msg.sender;
    creationBlock = block.number;
  }

  function gracePhaseEndBlock() internal view returns(uint) {
    return creationBlock + gracePhase;
  }

  function inGracePhase() public view returns(bool) {
    return block.number <= gracePhaseEndBlock();
  }

  modifier isInGracePhase() {
    require(inGracePhase(), 'This auction is in grace phase');
    _;
  }

  modifier isNotInGracePhase() {
    require(!inGracePhase(), 'This auction is not in grace phase');
    _;
  }

  modifier isNotSeller() {
    require(msg.sender != seller, 'The seller cannot bid');
    _;
  }

  function forceGracePhaseTermination() external isInGracePhase {
    gracePhase = block.number - creationBlock;
  }
}