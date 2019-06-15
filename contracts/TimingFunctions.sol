pragma solidity >=0.4.21 <0.6.0;

import "./ITimingFunction.sol";

// This file contains some examples of implementation of the ITimingFunction interface

// Contract for a linear increase from 0 to value based on time
contract Linear is ITimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint) {
    return value * time / duration;
  }
}

// Contract for a quadratic increase from 0 to value based on time
contract Quadratic is ITimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint) {
    return value * (time ** 2) / (duration ** 2);
  }
}
