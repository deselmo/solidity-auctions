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

  address private _winner;

  event LogStartAuction(
    address seller,
    uint reservePrice,
    uint initialPrice,
    uint duration
  );
  event LogEndAuction();

  event LogBid(
    bool win,
    address bidder,
    uint bid,
    uint price,
    uint blockNumber
  );

  constructor(
    uint _reservePrice,
    uint _initialPrice,
    uint _duration,
    TimingFunction _timingFunction
  ) public {
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

  function winner() public view
    isAuctionTerminated
    returns(address)
  {
    require(_winner != address(0), 'No one won this auction');
    return _winner;
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

    if(msg.value < _currentPrice) {
      msg.sender.transfer(msg.value);
      emit LogBid(false, msg.sender, msg.value, _currentPrice, block.number);
      return;
    }

    uint difference = msg.value - _currentPrice;

    if(difference > 0) {
      msg.sender.transfer(difference);
    }

    _winner = msg.sender;
    seller.transfer(_currentPrice);

    emit LogBid(true, msg.sender, msg.value, _currentPrice, block.number);

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

    function forceBidPhaseTermination() external isInBidPhase {
      bidPhaseLength = block.number + 1 - bidPhaseStartBlock();
    }
  // }

  function auctionTerminated() public view returns(bool) {
    return block.number >= bidPhaseEndBlock();
  }
}
