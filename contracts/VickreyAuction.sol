pragma solidity >=0.5.0 <0.6.0;

// file containing the abstract contract Auction
import "./Auction.sol";

contract VickreyAuction is Auction {
  // Variables defined in the constructor
  uint public reservePrice;
  uint public lengthCommitmentPhase;
  uint public lengthWithdrawalPhase;
  uint public lengthPpeningPhase;
  uint public depositRequirement;

  // Map containing the commitment associated with each bidder address
  mapping (address => bytes32) private commitments;

  // Value of the bid of the winner
  uint private winnerValue;

  // Value that the winner have to pay (sealed-bid second-price)
  uint private winningPrice;

  // Value of burned ethereum, stored for debug
  uint private _burnedValue;

  // Logs
  event LogStartAuction(
    address seller,
    uint lengthCommitmentPhase,
    uint lengthWithdrawalPhase,
    uint lengthPpeningPhase,
    uint depositRequirement
  );

  event LogBidCommitment(
    address bidder,
    bytes32 commitment
  );

  event LogWithdraw(
    address bidder
  );

  event LogOpen(
    address bidder,
    bytes32 commitment,
    bytes32 nonce,

    // value bid by the bidder
    uint bid
  );

  event LogChangeCurrentWinner(
    address currentWinner,
    uint bid
  );

  event LogFinalized(
    address winner,

    // value bid by the winner
    uint bid,

    // value that the winner have to pay
    uint winningPrice,

    uint burnedValue
  );

  constructor(
    uint _reservePrice,
    uint _lengthCommitmentPhase,
    uint _lengthWithdrawalPhase,
    uint _lengthPpeningPhase,
    uint _depositRequirement,
    bool _debug
  ) Auction(_debug) public {
    require(_lengthCommitmentPhase > 0,
            '_lengthCommitmentPhase must be bigger than 0');
    require(_lengthPpeningPhase > 0,
            '_lengthPpeningPhase must be bigger than 0');

    reservePrice = _reservePrice;
    lengthCommitmentPhase = _lengthCommitmentPhase;
    lengthWithdrawalPhase = _lengthWithdrawalPhase;
    lengthPpeningPhase = _lengthPpeningPhase;
    depositRequirement = _depositRequirement;

    // winningPrice is initialized with the reservePrice
    winningPrice = reservePrice;

    emit LogStartAuction(
      seller,
      lengthCommitmentPhase,
      lengthWithdrawalPhase,
      lengthPpeningPhase,
      depositRequirement
    );
  }

  // Debug function, compute the commitment that bidder can submit in commitment phase
  function debugComputeKeccak256(bytes32 nonce, uint value) external view
    isDebug
    returns(bytes32)
  {
    return keccak256(abi.encode(nonce, value));
  }


  // Debug function, get how mutch value has been burned
  function debugBurnedValue() external view
    isDebug
    returns(uint)
  {
    return _burnedValue;
  }

  // Private function
  // return true if a commitment is present for the msg.sender
  //        false otherwise
  function senderCommitmentPresent() private view returns(bool) {
    return commitments[msg.sender] != 0;
  }

  // Modifier used to prevent a function from being called if the sender did not send a commitment
  modifier isSenderCommitmentPresent() {
    require(senderCommitmentPresent(),
            'There is no commitment for this bidder');
    _;
  }

  // Modifier used to prevent a function from being called if the sender sent a commitment
  modifier isNotSenderCommitmentPresent() {
    require(!senderCommitmentPresent(),
            'There is already a commitment for this bidder');
    _;
  }

  /**
   * The commitment phase start after the grace phase and end after
   * lengthCommitmentPhase blocks
   */
  // commitmentPhase {

    // Allow a bidder to make a commitment
    function submitBidCommitment(bytes32 commitment) external payable
      isInCommitmentPhase
      isNotSeller
      isNotSenderCommitmentPresent
    {
      require(msg.value == depositRequirement,
              'The value sent must be equal to depositRequirement');

      commitments[msg.sender] = commitment;

      emit LogBidCommitment(msg.sender, commitment);
    }


    // Debug function, get the commitment for the caller bidder
    function debugGetBidCommitment() external view
      isDebug
      isInCommitmentPhase
      isNotSeller
      isSenderCommitmentPresent
      returns(bytes32)
    {
      return commitments[msg.sender];
    }


    // functions for managing commitment phase
    function commitmentPhaseStartBlock() private view returns(uint) {
      return gracePhaseEndBlock();
    }

    function commitmentPhaseEndBlock() private view returns(uint) {
      return commitmentPhaseStartBlock() + lengthCommitmentPhase;
    }

    function inCommitmentPhase() public view returns(bool) {
      return block.number >= commitmentPhaseStartBlock() &&
             block.number < commitmentPhaseEndBlock();
    }

    modifier isInCommitmentPhase() {
      require(inCommitmentPhase(),
              'It is necessary to be in commitment phase to call this operation');
      _;
    }

    function debugTerminateCommitmentPhase() external isDebug isInCommitmentPhase {
      lengthCommitmentPhase = block.number + 1 - commitmentPhaseStartBlock();
    }
  // }


  /**
   * The withdrawal phase start after the commitment phase and end after
   * lengthWithdrawalPhase blocks
   */
  // withdrawalPhase {

    // Allows a bidder to withdraw from the auction
    // and get half of the paid depositRequirement
    function withdraw() external
      isInWithdrawalPhase
      isNotSeller
      isSenderCommitmentPresent
    {
      delete commitments[msg.sender];
      msg.sender.transfer(depositRequirement / 2);

      emit LogWithdraw(msg.sender);
    }


    // functions for managing withdrawal phase
    function withdrawalPhaseStartBlock() private view returns(uint) {
      return commitmentPhaseEndBlock();
    }

    function withdrawalPhaseEndBlock() private view returns(uint) {
      return withdrawalPhaseStartBlock() + lengthWithdrawalPhase;
    }

    function inWithdrawalPhase() public view returns(bool) {
      return block.number >= withdrawalPhaseStartBlock() &&
             block.number < withdrawalPhaseEndBlock();
    }

    modifier isInWithdrawalPhase() {
      require(inWithdrawalPhase(),
              'It is necessary to be in withdrawal phase to call this operation');
      _;
    }

    function debugTerminateWithdrawalPhase() external isDebug isInWithdrawalPhase {
      lengthWithdrawalPhase = block.number + 1 - withdrawalPhaseStartBlock();
    }
  // }


  /**
   * The opening phase start after the withdrawal phase and end after
   * lengthOpeningPhase blocks
   */
  // openingPhase {

    // Allows a bidder to open its commitment;
    // a limit has not been imposed on the number of attempts a user can make;
    // if there's a new higher bid, the previous bidder with high bid is immediately refunded
    // if the bid is not enough high, the bidder is immediately refunded
    function open(bytes32 nonce) external payable
      isInOpeningPhase
      isNotSeller
      isSenderCommitmentPresent
    {
      require(
        keccak256(abi.encode(nonce, msg.value)) == commitments[msg.sender],
        'Invalid nonce or value'
      );

      emit LogOpen(msg.sender, commitments[msg.sender], nonce, msg.value);

      msg.sender.transfer(depositRequirement);
      delete commitments[msg.sender];

      if(msg.value >= reservePrice &&
         msg.value > winnerValue
      ) {
        if(_winner != address(0)) {
          _winner.transfer(winnerValue);
          winningPrice = winnerValue;
        }
        winnerValue = msg.value;
        _winner = msg.sender;

        emit LogChangeCurrentWinner(_winner, winnerValue);
      }
      else {
        msg.sender.transfer(msg.value);
      }

      // if there is a bid with the same value of the winning price
      // then the price to pay is equal to the highest bid
      if(_winner != address(0) && msg.value == winnerValue) {
        winningPrice = winnerValue;
      }
    }


    // functions for managing opening phase
    function openingPhaseStartBlock() private view returns(uint) {
      return withdrawalPhaseEndBlock();
    }

    function openingPhaseEndBlock() private view returns(uint) {
      return openingPhaseStartBlock() + lengthPpeningPhase;
    }

    function inOpeningPhase() public view returns(bool) {
      return block.number >= openingPhaseStartBlock() &&
             block.number < openingPhaseEndBlock();
    }

    modifier isInOpeningPhase() {
      require(inOpeningPhase(),
              'It is necessary to be in opening phase to call this operation');
      _;
    }

    function debugTerminateOpeningPhase() external isDebug isInOpeningPhase {
      lengthPpeningPhase = block.number + 1 - openingPhaseStartBlock();
    }
  // }


  /**
   * The finalization phase start after the opening phase and end when
   * the finalize function is called
   */
  // finalizationPhase {
    function finalizationPhaseStartBlock() private view returns(uint) {
      return openingPhaseEndBlock();
    }

    // private variable which indicates whether the contract has been finalized or not
    bool private finalized = false;

    function inFinalizationPhase() public view returns(bool) {
      return block.number >= finalizationPhaseStartBlock() &&
             !finalized;
    }

    modifier isInFinalizationPhase() {
      require(inFinalizationPhase(),
              'It is necessary to be in finalization phase to call this operation');
      _;
    }


    // Finalize and terminate the contract;
    // this function is callable only in finalization phase;
    // If there is a winner: the winning value is sent to the seller
    //                       and the winner is immediately refaunded
    function finalize() external isInFinalizationPhase {
      finalized = true;

      if(_winner != address(0)) {
        if(winnerValue > winningPrice) {
          _winner.transfer(winnerValue - winningPrice);
        }

        seller.transfer(winningPrice);
      }

      _burnedValue = address(this).balance;
      if(_burnedValue > 0) {
        address(0).transfer(_burnedValue);
      }

      emit LogFinalized(_winner, winnerValue, winningPrice, _burnedValue);
    }

    // for the finalization phase there is not a debug function to force
    // the termination because there are not time constraints
  // }


  // The Vickrey auction terminated if the finalize function was successfully called
  function terminated() public view returns(bool) {
    return finalized;
  }
}