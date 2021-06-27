//  SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface IRewardsOnlyGauge {
    function claim_rewards(address addr, address receiver) external;

    function withdraw(uint256 value, bool claim_rewards) external;
    
    function deposit(uint256 value, address addr, bool claim_rewards) external;
}