pragma solidity >=0.5.0 <0.6.0;

// file containing the abstract contract Auction
import "./Auction.sol";

// file containing only the interface ITimingFunction
// some concrete contracts implementing this interface are in the file TimingFunctions.sol
import "./ITimingFunction.sol";

contract DutchAuction is Auction {
  // Variables defined in the constructor
  uint public reservePrice;
  uint public initialPrice;
  uint public lengthBidPhase;
  ITimingFunction public timingFunction;

  // Stored variables to avoid having to perform the same calculation several times
  uint private lengthBidPhaseMinusOne;
  uint private maxPriceOffset;

  // Logs
  event LogStartAuction(
    address seller,
    uint reservePrice,
    uint initialPrice,
    uint duration
  );
  event LogSold(
    address winner,

    // value bid by the winner
    uint bid,

    // value of the price during the winning bid
    uint currentPrice
  );

  constructor(
    uint _reservePrice,
    uint _initialPrice,
    uint _duration,
    ITimingFunction _timingFunction,
    bool _debug
  ) Auction(_debug) public {
    require(_initialPrice > 0,
            '_initialPrice must be bigger than 0');
    require(_initialPrice >= _reservePrice,
            '_initialPrice must be bigger than or equal to _reservePrice');

    reservePrice = _reservePrice;
    initialPrice = _initialPrice;
    lengthBidPhase = _duration;
    timingFunction = _timingFunction;

    maxPriceOffset = initialPrice - reservePrice;
    lengthBidPhaseMinusOne = lengthBidPhase - 1;

    emit LogStartAuction(
      seller,
      reservePrice,
      initialPrice,
      lengthBidPhase
    );
  }

  // Calculate the current price in the auction
  function currentPrice() public view
    isInBidPhase
    returns(uint)
  {
    // timingFunction will return a value gradually increasing in the block number
    return initialPrice - timingFunction.compute(
      maxPriceOffset,
      block.number - bidPhaseStartBlock(),
      lengthBidPhaseMinusOne
    );
  }

  // Allow a bidder to make a bid
  // the auction ends immediately when there is a valid bid
  function bid() public payable
    isInBidPhase
    isNotSeller
  {
    uint _currentPrice = currentPrice();

    assert(_currentPrice <= initialPrice);

    require(msg.value >= _currentPrice,
            'the bid is not high enough');

    _winner = msg.sender;
    seller.transfer(msg.value);

    emit LogSold(msg.sender, msg.value, _currentPrice);

    return;
  }


  /**
   * The bid phase start after the grace phase and end after
   * lengthBidPhase blocks
   */
  // bidPhase {
    function bidPhaseStartBlock() internal view returns(uint) {
      return gracePhaseEndBlock();
    }

    function bidPhaseEndBlock() internal view returns(uint) {
      return bidPhaseStartBlock() + lengthBidPhase;
    }

    function inBidPhase() public view returns(bool) {
      return _winner == address(0) &&
            block.number >= bidPhaseStartBlock() &&
            block.number < bidPhaseEndBlock();
    }

    modifier isInBidPhase() {
      require(inBidPhase(),
              'It is necessary to be in bid phase to call this operation');
      _;
    }

    function debugTerminateBidPhase() external isDebug isInBidPhase {
      lengthBidPhase = block.number + 1 - bidPhaseStartBlock();
    }
  // }

  // The dutch auction terminated if there is a winner or the bid phase is terminated
  function terminated() public view returns(bool) {
    return _winner != address(0) ||
           block.number >= bidPhaseEndBlock();
  }
}
