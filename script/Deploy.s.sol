// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {NFTStaking} from "../src/NFTStaking.sol";
import {StakeRewardToken} from "../src/StakeRewardToken.sol";
import {MockNFT} from "../src/MockNFT.sol";

/**
 * @title Deploy
 * @notice Deployment script for NFT Staking Protocol
 * @dev Deploy to ZKSync Era testnet:
 *      forge script script/Deploy.s.sol:Deploy --rpc-url $ZKSYNC_SEPOLIA_RPC --account <account-name> --broadcast --verify
 *      Or: forge script script/Deploy.s.sol:Deploy --rpc-url $ZKSYNC_SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast --verify
 */
contract Deploy is Script {
    function run() external {
        // Get the deployer address from available wallets
        // When using --account, Foundry will have the wallet available
        address[] memory wallets = vm.getWallets();
        address deployer;

        if (wallets.length > 0) {
            // Use the first available wallet (from --account flag)
            deployer = wallets[0];
        } else {
            // Fallback to msg.sender if no wallets available
            deployer = msg.sender;
        }

        // Treasury address - can be set via env or defaults to deployer
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);

        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);

        // Start broadcast - Foundry will use the account from --account or --private-key flags
        // This ensures the broadcast address matches deployer
        vm.startBroadcast(deployer);

        // 1. Deploy Reward Token with deployer as admin
        StakeRewardToken rewardToken = new StakeRewardToken(
            "NFT Stake Rewards",
            "NFTR",
            deployer
        );
        console.log("StakeRewardToken deployed at:", address(rewardToken));

        // 2. Deploy Staking Contract
        NFTStaking staking = new NFTStaking(address(rewardToken), treasury);
        console.log("NFTStaking deployed at:", address(staking));

        // 3. Grant MINTER_ROLE to staking contract
        // Since deployer is the admin and also the broadcast address, this will work
        rewardToken.grantRole(rewardToken.MINTER_ROLE(), address(staking));
        console.log("Granted MINTER_ROLE to staking contract");

        // 4. Deploy Mock NFT for testing (optional for production)
        MockNFT mockNFT = new MockNFT("Test Staking NFT", "TSNFT");
        console.log("MockNFT deployed at:", address(mockNFT));

        // 5. Whitelist the mock NFT collection
        staking.addCollection(address(mockNFT));
        console.log("Added MockNFT to whitelist");

        vm.stopBroadcast();

        // Log summary
        console.log("\n=== Deployment Summary ===");
        console.log("StakeRewardToken:", address(rewardToken));
        console.log("NFTStaking:", address(staking));
        console.log("MockNFT:", address(mockNFT));
        console.log("Treasury:", treasury);
        console.log("========================\n");
    }
}

/**
 * @title DemoTransactions
 * @notice Script to demonstrate all protocol features with transactions
 * @dev Run after deployment to generate demo transactions for submission
 *      forge script script/Deploy.s.sol:DemoTransactions --rpc-url $ZKSYNC_SEPOLIA_RPC --account <account-name> --broadcast
 */
contract DemoTransactions is Script {
    function run() external {
        // Get the deployer address from available wallets
        address[] memory wallets = vm.getWallets();
        address deployer = wallets.length > 0 ? wallets[0] : msg.sender;

        // Load deployed contract addresses from environment
        address stakingAddr = vm.envAddress("STAKING_ADDRESS");
        address mockNftAddr = vm.envAddress("MOCK_NFT_ADDRESS");
        address rewardTokenAddr = vm.envAddress("REWARD_TOKEN_ADDRESS");

        NFTStaking staking = NFTStaking(stakingAddr);
        MockNFT mockNFT = MockNFT(mockNftAddr);
        StakeRewardToken rewardToken = StakeRewardToken(rewardTokenAddr);

        console.log("Running demo transactions...");
        console.log("Deployer:", deployer);

        // Start broadcast with deployer address
        vm.startBroadcast(deployer);

        // Demo 1: Mint and Stake NFTs
        console.log("\n=== Demo 1: Stake NFTs ===");
        uint256 tokenId1 = mockNFT.mint(deployer);
        uint256 tokenId2 = mockNFT.mint(deployer);
        console.log("Minted tokenId:", tokenId1);
        console.log("Minted tokenId:", tokenId2);

        mockNFT.approve(address(staking), tokenId1);
        mockNFT.approve(address(staking), tokenId2);

        staking.stake(address(mockNFT), tokenId1);
        console.log("Staked tokenId:", tokenId1);

        staking.stake(address(mockNFT), tokenId2);
        console.log("Staked tokenId:", tokenId2);

        // Demo 2: Check pending rewards
        console.log("\n=== Demo 2: Check Rewards ===");
        uint256 pending1 = staking.pendingRewards(address(mockNFT), tokenId1);
        console.log("Pending rewards for token 1:", pending1);

        // Demo 3: Claim rewards (without unstaking)
        console.log("\n=== Demo 3: Claim Rewards ===");
        staking.claimRewards(address(mockNFT), tokenId1);
        uint256 balance = rewardToken.balanceOf(deployer);
        console.log("Claimed rewards, new balance:", balance);

        // Demo 4: Instant unstake with penalty (token 2)
        console.log("\n=== Demo 4: Instant Unstake with Penalty ===");
        uint256 penaltyBps = staking.currentPenalty(address(mockNFT), tokenId2);
        console.log("Current penalty (bps):", penaltyBps);

        staking.instantUnstake(address(mockNFT), tokenId2);
        console.log("Instant unstaked tokenId:", tokenId2);

        uint256 treasuryBalance = rewardToken.balanceOf(staking.treasury());
        console.log("Treasury balance (penalties):", treasuryBalance);

        vm.stopBroadcast();

        console.log("\n=== Demo Complete ===");
        console.log(
            "Token 1 still staked (wait for lock period to unstake without penalty)"
        );
        console.log("Token 2 unstaked with penalty");
    }
}

/**
 * @title UnstakeAfterLock
 * @notice Script to unstake after lock period (no penalty)
 * @dev Run 7+ days after staking to demonstrate penalty-free unstake
 *      forge script script/Deploy.s.sol:UnstakeAfterLock --rpc-url $ZKSYNC_SEPOLIA_RPC --account <account-name> --broadcast
 */
contract UnstakeAfterLock is Script {
    function run() external {
        // Get the deployer address from available wallets
        address[] memory wallets = vm.getWallets();
        address deployer = wallets.length > 0 ? wallets[0] : msg.sender;

        address stakingAddr = vm.envAddress("STAKING_ADDRESS");
        address mockNftAddr = vm.envAddress("MOCK_NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");

        NFTStaking staking = NFTStaking(stakingAddr);

        console.log("Unstaking token after lock period...");
        console.log("TokenId:", tokenId);

        // Check if lock period has ended
        uint256 remaining = staking.lockTimeRemaining(
            address(mockNftAddr),
            tokenId
        );
        console.log("Lock time remaining (seconds):", remaining);

        if (remaining > 0) {
            console.log("ERROR: Lock period not yet ended!");
            console.log("Wait", remaining, "more seconds");
            return;
        }

        // Start broadcast with deployer address
        vm.startBroadcast(deployer);

        staking.unstake(address(mockNftAddr), tokenId);
        console.log("Successfully unstaked without penalty!");

        vm.stopBroadcast();
    }
}
