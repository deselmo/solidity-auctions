pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";
import "./TimingFunction.sol";

contract DutchAuction is Auction {
  uint public reservePrice;
  uint public initialPrice;
  uint public bidPhaseLength;
  TimingFunction public timingFunction;

  uint private bidPhaseLengthMinusOne;
  uint private maxPriceOffset;

  event LogStartAuction(
    address seller,
    uint reservePrice,
    uint initialPrice,
    uint duration
  );
  event LogSold(
    address winner,
    uint bid,
    uint currentPrice
  );

  constructor(
    uint _reservePrice,
    uint _initialPrice,
    uint _duration,
    TimingFunction _timingFunction,
    bool _debug
  ) Auction(_debug) public {
    require(_initialPrice > 0,
            '_initialPrice must be bigger than 0');
    require(_initialPrice >= _reservePrice,
            '_initialPrice must be bigger than or equal to _reservePrice');

    reservePrice = _reservePrice;
    initialPrice = _initialPrice;
    bidPhaseLength = _duration;
    timingFunction = _timingFunction;

    maxPriceOffset = initialPrice - reservePrice;
    bidPhaseLengthMinusOne = bidPhaseLength - 1;

    emit LogStartAuction(
      seller,
      reservePrice,
      initialPrice,
      bidPhaseLength
    );
  }

  function currentPrice() public view
    isInBidPhase
    returns(uint)
  {
    return initialPrice - timingFunction.compute(
      maxPriceOffset,
      block.number - bidPhaseStartBlock(),
      bidPhaseLengthMinusOne
    );
  }

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

    emit LogEndAuction(true, msg.sender, msg.value, _currentPrice);

    return;
  }

  // bidPhase {
    function bidPhaseStartBlock() internal view returns(uint) {
      return gracePhaseEndBlock();
    }

    function bidPhaseEndBlock() internal view returns(uint) {
      return bidPhaseStartBlock() + bidPhaseLength;
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
      bidPhaseLength = block.number + 1 - bidPhaseStartBlock();
    }
  // }

  function terminated() public view returns(bool) {
    return _winner != address(0) ||
           block.number >= bidPhaseEndBlock();
  }
}
