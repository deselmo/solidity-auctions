pragma solidity >=0.5.0 <0.6.0;

interface TimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint);
}