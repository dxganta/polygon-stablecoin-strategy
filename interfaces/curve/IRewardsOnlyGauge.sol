//  SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface IRewardsOnlyGauge {
    /*
    @notice Claim available reward tokens for `_addr`
    @param _addr Address to claim for
    @param _receiver Address to transfer rewards to - if set to
                     ZERO_ADDRESS, uses the default reward receiver
                     for the caller
    */
    function claim_rewards(address addr, address receiver) external;


    /*
    @notice Withdraw `_value` LP tokens
    @dev Withdrawing also claims pending reward tokens
    @param _value Number of tokens to withdraw
    */
    function withdraw(uint256 value, bool claim_rewards) external;


    /*
    @notice Deposit `_value` LP tokens
    @dev Depositting also claims pending reward tokens
    @param _value Number of tokens to deposit
    @param _addr Address to deposit for
    */
    function deposit(uint256 value, address addr, bool claim_rewards) external;

    /*
    @notice Get the number of claimable reward tokens for a user
    @param addr Account to get reward amount for
    @param token Token to get reward amount for
    @return uint256 Claimable reward token amount
    */
    function claimable_reward_write(address addr, address token) external view returns (uint256);
}