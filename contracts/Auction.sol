pragma solidity >=0.5.0 <0.6.0;

contract Auction {
  uint internal gracePhaseLength = 4500; // ~ 5 minuts
  uint internal creationBlock;

  address payable public seller;
  address payable internal _winner;

  bool public debug = false;

  constructor(bool _debug) internal {
    seller = msg.sender;
    creationBlock = block.number;

    debug = _debug;
  }


  function winner() public view
    isAuctionTerminated
    returns(address)
  {
    require(_winner != address(0), 'No one won this auction');
    return _winner;
  }


  function dummyBlock() external payable isDebug { return; }


  modifier isNotSeller() {
    require(msg.sender != seller, 'The seller cannot bid');
    _;
  }

  // gracePhase {
    function gracePhaseStartBlock() internal view returns(uint) {
      return creationBlock + 1;
    }

    function gracePhaseEndBlock() internal view returns(uint) {
      return gracePhaseStartBlock() + gracePhaseLength;
    }

    function inGracePhase() public view returns(bool) {
      return block.number >= gracePhaseStartBlock() &&
            block.number < gracePhaseEndBlock();
    }

    modifier isInGracePhase() {
      require(inGracePhase(),
              'It is necessary to be in grace phase to call this operation');
      _;
    }

    function forceGracePhaseTermination() external isDebug isInGracePhase {
      gracePhaseLength = block.number + 1 - gracePhaseStartBlock();
    }
  // }

  function auctionTerminated() public view returns(bool);

  modifier isAuctionTerminated() {
    require(auctionTerminated(),
            'The auction must be completed to call this operation');
    _;
  }

  modifier isDebug() {
    require(debug, 'This operation is available only in debug mode');
    _;
  }
}