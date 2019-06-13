pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";

contract VickreyAuction is Auction {
  uint public reservePrice;
  uint public lengthCommitmentPhase;
  uint public lengthWithdrawalPhase;
  uint public lengthPpeningPhase;
  uint public depositRequirement;

  mapping (address => bytes32) private commitments;

  uint private winnerValue;
  uint private winningPrice;

  uint private _burnedValue;

  event LogStartAuction(
    address seller,
    uint lengthCommitmentPhase,
    uint lengthWithdrawalPhase,
    uint lengthPpeningPhase,
    uint depositRequirement
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

    winningPrice = reservePrice;

    emit LogStartAuction(
      seller,
      lengthCommitmentPhase,
      lengthWithdrawalPhase,
      lengthPpeningPhase,
      depositRequirement
    );
  }

  function debugComputeKeccak256(bytes32 nonce, uint value) external view
    isDebug
    returns(bytes32)
  {
    return keccak256(abi.encode(nonce, value));
  }

  function debugBurnedValue() external view
    isDebug
    returns(uint)
  {
    return _burnedValue;
  }

  function senderCommitmentPresent() private view returns(bool) {
    return commitments[msg.sender] != 0;
  }

  modifier isSenderCommitmentPresent() {
    require(senderCommitmentPresent(),
            'There is no commitment for this bidder');
    _;
  }

  modifier isNotSenderCommitmentPresent() {
    require(!senderCommitmentPresent(),
            'There is already a commitment for this bidder');
    _;
  }

  // commitmentPhase {
    function submitBidCommitment(bytes32 commitment) external payable
      isInCommitmentPhase
      isNotSeller
      isNotSenderCommitmentPresent
    {
      require(msg.value == depositRequirement,
              'The value sent must be equal to depositRequirement');

      commitments[msg.sender] = commitment;
    }

    function debugGetBidCommitment() external view
      isDebug
      isInCommitmentPhase
      isNotSeller
      isSenderCommitmentPresent
      returns(bytes32)
    {
      return commitments[msg.sender];
    }


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

  // withdrawalPhase {
    function withdraw() external
      isInWithdrawalPhase
      isNotSeller
      isSenderCommitmentPresent
    {
      delete commitments[msg.sender];
      msg.sender.transfer(depositRequirement / 2);
    }


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

  // openingPhase {
    function open(bytes32 nonce) external payable
      isInOpeningPhase
      isNotSeller
      isSenderCommitmentPresent
    {
      require(
        keccak256(abi.encode(nonce, msg.value)) == commitments[msg.sender],
        'Failed bid commitment opening'
      );

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
      }
      else {
        msg.sender.transfer(msg.value);
      }
    }

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

  // finalizationPhase {
    function finalizationPhaseStartBlock() private view returns(uint) {
      return openingPhaseEndBlock();
    }

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
    }
  // }

  function terminated() public view returns(bool) {
    return finalized;
  }
}