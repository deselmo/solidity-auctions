pragma solidity >=0.5.0 <0.6.0;

import "./Auction.sol";

contract VickreyAuction is Auction {
  uint public commitmentPhaseLength;
  uint public withdrawalPhaseLength;
  uint public openingPhaseLength;
  uint public depositRequirement;

  event LogStartAuction(
    address seller,
    uint commitmentPhaseLength,
    uint withdrawalPhaseLength,
    uint openingPhaseLength,
    uint depositRequirement
  );

  constructor(
    uint _commitmentPhaseLength,
    uint _withdrawalPhaseLength,
    uint _openingPhaseLength,
    uint _depositRequirement
  ) public {
    require(_commitmentPhaseLength > 0,
            '_commitmentPhaseLength must be bigger than 0');
    require(_openingPhaseLength > 0,
            '_openingPhaseLength must be bigger than 0');

    commitmentPhaseLength = _commitmentPhaseLength;
    withdrawalPhaseLength = _withdrawalPhaseLength;
    openingPhaseLength = _openingPhaseLength;
    depositRequirement = _depositRequirement;

    emit LogStartAuction(
      seller,
      commitmentPhaseLength,
      withdrawalPhaseLength,
      openingPhaseLength,
      depositRequirement
    );
  }

  // commitmentPhase {
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

    function forceCommitmentPhaseTermination() external isInCommitmentPhase {
      commitmentPhaseLength = block.number + 1 - commitmentPhaseStartBlock();
    }
  // }

  // withdrawalPhase {
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

    function forceWithdrawalPhaseTermination() external isInWithdrawalPhase {
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

    function forceOpeningPhaseTermination() external isInOpeningPhase {
      openingPhaseLength = block.number + 1 - openingPhaseStartBlock();
    }
  // }

  // finalizationPhase {
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
    }
  // }

  function auctionTerminated() public view returns(bool) {
    return finalized;
  }
}