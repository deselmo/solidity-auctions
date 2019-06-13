pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";

contract VickreyAuction is Auction {
  uint public reservePrice;
  uint public commitmentPhaseLength;
  uint public withdrawalPhaseLength;
  uint public openingPhaseLength;
  uint public depositRequirement;

  mapping (address => bytes32) private commitments;

  uint private winnerValue;
  uint private winningPrice;

  uint private _burnedValue;

  event LogStartAuction(
    address seller,
    uint commitmentPhaseLength,
    uint withdrawalPhaseLength,
    uint openingPhaseLength,
    uint depositRequirement
  );

  constructor(
    uint _reservePrice,
    uint _commitmentPhaseLength,
    uint _withdrawalPhaseLength,
    uint _openingPhaseLength,
    uint _depositRequirement,
    bool _debug
  ) Auction(_debug) public {
    require(_commitmentPhaseLength > 0,
            '_commitmentPhaseLength must be bigger than 0');
    require(_openingPhaseLength > 0,
            '_openingPhaseLength must be bigger than 0');

    reservePrice = _reservePrice;
    commitmentPhaseLength = _commitmentPhaseLength;
    withdrawalPhaseLength = _withdrawalPhaseLength;
    openingPhaseLength = _openingPhaseLength;
    depositRequirement = _depositRequirement;

    winningPrice = reservePrice;

    emit LogStartAuction(
      seller,
      commitmentPhaseLength,
      withdrawalPhaseLength,
      openingPhaseLength,
      depositRequirement
    );
  }

  function debugComputeKeccak256(bytes32 nonce, uint value) public view
    isDebug
    returns(bytes32)
  {
    return keccak256(abi.encode(nonce, value));
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

    function getBidCommitment() external view
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
      return commitmentPhaseStartBlock() + commitmentPhaseLength;
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
      commitmentPhaseLength = block.number + 1 - commitmentPhaseStartBlock();
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
      return withdrawalPhaseStartBlock() + withdrawalPhaseLength;
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
      withdrawalPhaseLength = block.number + 1 - withdrawalPhaseStartBlock();
    }
  // }

  // openingPhase {
    function openingPhaseStartBlock() private view returns(uint) {
      return withdrawalPhaseEndBlock();
    }

    function openingPhaseEndBlock() private view returns(uint) {
      return openingPhaseStartBlock() + openingPhaseLength;
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
      openingPhaseLength = block.number + 1 - openingPhaseStartBlock();
    }
  // }

  // finalizationPhase {
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


    function finalizationPhaseStartBlock() private view returns(uint) {
      return openingPhaseEndBlock();
    }

    bool public finalized = false;

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

      if(_winner != address(0) && winnerValue > winningPrice) {
        _winner.transfer(winnerValue - winningPrice);
      }

      _burnedValue = address(this).balance;
      address(0).transfer(_burnedValue);
    }
  // }

  function auctionTerminated() public view returns(bool) {
    return finalized;
  }
}