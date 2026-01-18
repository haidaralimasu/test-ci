// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/StakeRewardToken.sol";

// This wrapper initializes your contract with fixed values
contract EchidnaTester is StakeRewardToken {
    // Pass dummy values to the real constructor
    constructor() StakeRewardToken("MockToken", "MOCK", msg.sender) {
        // Any other setup logic can go here
    }

    function echidna_totalSupplyCorrect() public view returns (bool) {
        return totalSupply() <= 100 ether; // Example: Total supply must be less than or equal to 100 ether
    }
}
