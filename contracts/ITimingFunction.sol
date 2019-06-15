pragma solidity >=0.5.0 <0.6.0;

// Interface of the contract required for the DutchAuction contract.
// Compute function returns an uint between 0 and value;
// if time is equal to 0 the function is expected to return 0
// if time is equal to duration the function is expected to return value
// otherwise a value gradually higher based on the value of time
interface ITimingFunction {
  function compute(
    uint value,
    uint time,
    uint duration
  ) external pure returns(uint);
}
