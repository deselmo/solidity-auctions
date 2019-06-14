pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";
import "./ITimingFunction.sol";

contract DutchAuction is Auction {
  uint public reservePrice;
  uint public initialPrice;
  uint public lengthBidPhase;
  ITimingFunction public timingFunction;

  uint private lengthBidPhaseMinusOne;
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

  function currentPrice() public view
    isInBidPhase
    returns(uint)
  {
    return initialPrice - timingFunction.compute(
      maxPriceOffset,
      block.number - bidPhaseStartBlock(),
      lengthBidPhaseMinusOne
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

    emit LogSold(msg.sender, msg.value, _currentPrice);

    return;
  }

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

  function terminated() public view returns(bool) {
    return _winner != address(0) ||
           block.number >= bidPhaseEndBlock();
  }
}
