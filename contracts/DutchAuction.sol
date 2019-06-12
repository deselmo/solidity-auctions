pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";
import "./TimingFunction.sol";

contract DutchAuction is Auction {
  uint public reservePrice;
  uint public initialPrice;
  uint public duration;
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
    duration = _duration;
    timingFunction = _timingFunction;

    maxOffsetPrice = initialPrice - reservePrice;

    emit LogStartAuction(
      seller,
      reservePrice,
      initialPrice,
      duration
    );
  }

  function startBlock() private view returns(uint) {
    return creationBlock + gracePeriod + 1;
  }

  function endBlock() private view returns(uint) {
    return startBlock() + duration;
  }

  function winner() public view
    isTerminated
    returns(address)
  {
    require(_winner != address(0), 'No one won this auction');
    return _winner;
  }

  function currentPrice() public view
    isAuctionActive
    isNotTerminated
    returns(uint)
  {
    return initialPrice - timingFunction.compute(
      maxOffsetPrice,
      block.number - startBlock(),
      duration
    );
  }

  function bid() public payable
    isNotTerminated
  {
    super.bid();

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

  function terminated() public view returns(bool) {
    return _winner != address(0) || block.number > endBlock();
  }

  modifier isTerminated() {
    require(terminated(), 'This auction is yet not terminated');
    _;
  }

  modifier isNotTerminated() {
    require(!terminated(), 'This auction is terminated');
    _;
  }

  function forceBidPeriodTermination() external
    isAuctionActive
    isNotTerminated
  {
    duration = block.number - startBlock();
  }
}
