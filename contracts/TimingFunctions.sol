pragma solidity >=0.4.21 <0.6.0;

import "./TimingFunction.sol";

contract Linear is TimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint) {
    return value * time / duration;
  }
}

contract Quadratic is TimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint) {
    return value * (time ** 2) / (duration ** 2);
  }
}
