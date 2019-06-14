pragma solidity >=0.4.21 <0.6.0;

import "./ITimingFunction.sol";

contract Linear is ITimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint) {
    return value * time / duration;
  }
}

contract Quadratic is ITimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint) {
    return value * (time ** 2) / (duration ** 2);
  }
}
