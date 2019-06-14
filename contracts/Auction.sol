pragma solidity >=0.5.0 <0.6.0;

// Abstract contract for an auction
contract Auction {
  // Duration of the grace phase, ~ 5 minuts
  uint internal lengthGracePhase = 20;

  // Block number in which the auction is created
  uint internal creationBlock;

  // Creator of the contract,
  // in this contract the seller and the auctioneer are the same entity
  address payable public seller;

  // Address of the winner of the auction
  address payable internal _winner;

  // Flag indicating if the contract is in debug mode
  bool public debug = false;


  // Internal constructor of the abstract contract
  constructor(bool _debug) internal {
    seller = msg.sender;
    creationBlock = block.number;

    debug = _debug;
  }


  /**
   * Get the winner of the auction, callable only if the auction is terminated
   */
  function winner() public view
    isTerminated
    returns(address)
  {
    require(_winner != address(0), 'No one won this auction');
    return _winner;
  }

  /**
   * Debug function, get the balance of this auction
   */
  function debugBalance() public view isDebug returns(uint) {
    return address(this).balance;
  }

  /**
   * Debug function, create a dummy block, to pass the time
   */
  function debugDummyBlock() external payable isDebug { return; }


  /**
   * Modifier used to prevent a function from being called by the seller
   */
  modifier isNotSeller() {
    require(msg.sender != seller, 'The seller cannot bid');
    _;
  }

  /**
   * The grace phace start after the action creation and end after
   * lengthGracePhase blocks
   */
  // gracePhase {
    function gracePhaseStartBlock() internal view returns(uint) {
      return creationBlock + 1;
    }

    function gracePhaseEndBlock() internal view returns(uint) {
      return gracePhaseStartBlock() + lengthGracePhase;
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

    function debugTerminateGracePhase() external isDebug isInGracePhase {
      lengthGracePhase = block.number + 1 - gracePhaseStartBlock();
    }
  // }


  /**
   * Abstract function that return if the auction is terminated
   *
   * The responsibility to decide when the contract is terminated is left to the
   * concrete contract
   */
  function terminated() public view returns(bool);


  /**
   * Modifier used to prevent a function from being called if the auction is terminated
   */
  modifier isTerminated() {
    require(terminated(),
            'The auction must be completed to call this operation');
    _;
  }

  /**
   * Modifier used to prevent a function from being called if the auction is not
   * in debug mode
   */
  modifier isDebug() {
    require(debug, 'This operation is available only in debug mode');
    _;
  }
}