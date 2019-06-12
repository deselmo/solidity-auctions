pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";
import "./TimingFunction.sol";

contract DutchAuction is Auction {
  uint public reservePrice;
  uint public initialPrice;
  uint public bidPhaseLength;
  TimingFunction public timingFunction;

  uint private maxOffsetPrice;

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
    require(_initialPrice > 0, '_initialPrice must be bigger than 0');

    reservePrice = _reservePrice;
    initialPrice = _initialPrice;
    bidPhaseLength = _duration;
    timingFunction = _timingFunction;

    maxOffsetPrice = initialPrice - reservePrice;

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
      maxOffsetPrice,
      block.number - bidPhaseStartBlock(),
      bidPhaseLength
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


  function bidPhaseStartBlock() internal view returns(uint) {
    return gracePhaseEndBlock() + 1;
  }

  function bidPhaseEndBlock() internal view returns(uint) {
    return bidPhaseStartBlock() + bidPhaseLength;
  }

  function inBidPhase() public view returns(bool) {
    return _winner == address(0) &&
           block.number >= bidPhaseStartBlock() &&
           block.number <= bidPhaseEndBlock();
  }

  modifier isInBidPhase() {
    require(inBidPhase(),
           'It is necessary to be in bid phase to call this operation');
    _;
  }

  function forceBidPhaseTermination() external isInBidPhase {
    bidPhaseLength = block.number - bidPhaseStartBlock();
  }


  function auctionTerminated() public view returns(bool) {
    return block.number > bidPhaseEndBlock();
  }
}
