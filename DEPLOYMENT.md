# Deployment Guide

This document provides instructions for deploying the NFT Staking Protocol to ZKSync Era testnet.

**✅ Deployment Status**: Successfully deployed and verified on ZKSync Era Sepolia testnet

## Why ZKSync Era?

We chose ZKSync Era Sepolia testnet for deployment because:

1. **Low Transaction Costs**: ZKSync Era's rollup architecture significantly reduces gas costs
2. **EVM Compatibility**: Full compatibility with Solidity contracts
3. **Fast Finality**: Quick transaction confirmation times
4. **Active Ecosystem**: Growing DeFi and NFT ecosystem
5. **Easy Verification**: Built-in contract verification support

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- A wallet with ZKSync Era Sepolia testnet ETH
- [Get testnet ETH from faucet](https://portal.zksync.io/faucet)

## Environment Setup

Create a `.env` file in the project root (optional):

```bash
# Optional (defaults to deployer address)
TREASURY_ADDRESS=0x...

# For demo transactions (set after initial deployment)
STAKING_ADDRESS=0xcB64C452ED4E927404b1e5FA6EE643eD9E222407
MOCK_NFT_ADDRESS=0x3c21DB69Df3e069806AA55C4EbD54519B4504815
REWARD_TOKEN_ADDRESS=0xe6078C23896C989Bf440D97fb2AbfD4bA386cB87
```

Load environment variables (if using .env):

```bash
source .env
```

> **Note**: Private keys are supplied dynamically via `--account` or `--private-key` flags for better security.

## Deployment Steps

### 1. Deploy All Contracts

**Using Foundry account (recommended):**

First, add your account to Foundry:

```bash
cast wallet import deployer --interactive
```

Then deploy:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://sepolia.era.zksync.dev \
  --account deployer \
  --broadcast \
  --verify \
  --verifier etherscan \
  --verifier-url https://explorer.sepolia.era.zksync.dev/contract_verification \
  --etherscan-api-key IXC6WG7QKETAQB59T6B8XVMY31M4VPMNU9
```

> **Note**: The Etherscan API key is also configured in `foundry.toml`, but passing it explicitly with `--etherscan-api-key` ensures ZKSync verifier uses it correctly.

**Or using private key directly:**

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://sepolia.era.zksync.dev \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier etherscan \
  --verifier-url https://explorer.sepolia.era.zksync.dev/contract_verification \
  --etherscan-api-key IXC6WG7QKETAQB59T6B8XVMY31M4VPMNU9
```

**Expected Output:**

```
Deployer: 0x...
Treasury: 0x...
StakeRewardToken deployed at: 0x...
NFTStaking deployed at: 0x...
MockNFT deployed at: 0x...
```

### 2. Save Contract Addresses

After deployment, update your `.env`:

```bash
STAKING_ADDRESS=0xcB64C452ED4E927404b1e5FA6EE643eD9E222407
MOCK_NFT_ADDRESS=0x3c21DB69Df3e069806AA55C4EbD54519B4504815
REWARD_TOKEN_ADDRESS=0xe6078C23896C989Bf440D97fb2AbfD4bA386cB87
```

### 3. Run Demo Transactions

This script demonstrates all protocol features:

**Using Foundry account:**

```bash
source .env  # Load contract addresses

forge script script/Deploy.s.sol:DemoTransactions \
  --rpc-url https://sepolia.era.zksync.dev \
  --account deployer \
  --broadcast
```

**Or using private key:**

```bash
source .env  # Load contract addresses

forge script script/Deploy.s.sol:DemoTransactions \
  --rpc-url https://sepolia.era.zksync.dev \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Demonstrates:**

- Staking NFTs
- Checking pending rewards
- Claiming rewards
- Instant unstaking with penalty
- Treasury receiving penalty fees

### 4. Unstake After Lock Period (Optional)

Wait 7 days, then run:

**Using Foundry account:**

```bash
export TOKEN_ID=<your-staked-token-id>
export STAKING_ADDRESS=0xcB64C452ED4E927404b1e5FA6EE643eD9E222407
export MOCK_NFT_ADDRESS=0x3c21DB69Df3e069806AA55C4EbD54519B4504815

forge script script/Deploy.s.sol:UnstakeAfterLock \
  --rpc-url https://sepolia.era.zksync.dev \
  --account deployer \
  --broadcast
```

**Or using private key:**

```bash
export TOKEN_ID=<your-staked-token-id>
export STAKING_ADDRESS=0xcB64C452ED4E927404b1e5FA6EE643eD9E222407
export MOCK_NFT_ADDRESS=0x3c21DB69Df3e069806AA55C4EbD54519B4504815

forge script script/Deploy.s.sol:UnstakeAfterLock \
  --rpc-url https://sepolia.era.zksync.dev \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Deployed Contract Addresses

| Contract         | Address                                      | Verified                                                                                                  |
| ---------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| StakeRewardToken | `0xe6078C23896C989Bf440D97fb2AbfD4bA386cB87` | [View on Explorer](https://sepolia.explorer.zksync.io/address/0xe6078C23896C989Bf440D97fb2AbfD4bA386cB87) |
| NFTStaking       | `0xcB64C452ED4E927404b1e5FA6EE643eD9E222407` | [View on Explorer](https://sepolia.explorer.zksync.io/address/0xcB64C452ED4E927404b1e5FA6EE643eD9E222407) |
| MockNFT          | `0x3c21DB69Df3e069806AA55C4EbD54519B4504815` | [View on Explorer](https://sepolia.explorer.zksync.io/address/0x3c21DB69Df3e069806AA55C4EbD54519B4504815) |
| Treasury         | `0xe34b40f38217f9Dc8c3534735f7f41B2cDA73A75` | -                                                                                                         |

## Transaction Links

### Deployment Transactions

| Action                   | Transaction Hash                                                                                                                                                               | Block   |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| Deploy StakeRewardToken  | [0x8e5b463088ff324a9a5b0169182e4c2586e2e486790789005e8614997924a069](https://sepolia.explorer.zksync.io/tx/0x8e5b463088ff324a9a5b0169182e4c2586e2e486790789005e8614997924a069) | 6526320 |
| Deploy NFTStaking        | [0xd28e0a58bdf152f3d143a913fd840906630223279496931a78e097ae797a8856](https://sepolia.explorer.zksync.io/tx/0xd28e0a58bdf152f3d143a913fd840906630223279496931a78e097ae797a8856) | 6526321 |
| Grant MINTER_ROLE        | [0x44afffb38f65f9b65b84de5c66d24632adf96e099733fbd67072f2d517c73e21](https://sepolia.explorer.zksync.io/tx/0x44afffb38f65f9b65b84de5c66d24632adf96e099733fbd67072f2d517c73e21) | 6526322 |
| Deploy MockNFT           | [0xa9a747d4fd0c4499d3af24f615271a59e94e0f7e6b5ec4343fed7608197c60ea](https://sepolia.explorer.zksync.io/tx/0xa9a747d4fd0c4499d3af24f615271a59e94e0f7e6b5ec4343fed7608197c60ea) | 6526323 |
| Add MockNFT to Whitelist | [0x37d68ffb196bf8c4be7917accfa1b8abfe223fd17cd2668eedfa74eb4e645f91](https://sepolia.explorer.zksync.io/tx/0x37d68ffb196bf8c4be7917accfa1b8abfe223fd17cd2668eedfa74eb4e645f91) | 6526325 |

### Demo Transactions

> **Note**: Run the `DemoTransactions` script to generate these transactions

| Action                         | Transaction Hash                           |
| ------------------------------ | ------------------------------------------ |
| Stake NFT #1                   | Run `DemoTransactions` script              |
| Stake NFT #2                   | Run `DemoTransactions` script              |
| Claim Rewards                  | Run `DemoTransactions` script              |
| Instant Unstake (with penalty) | Run `DemoTransactions` script              |
| Normal Unstake (after lock)    | Run `UnstakeAfterLock` script after 7 days |

## Verification

Contracts can be verified on the ZKSync Era Sepolia explorer:

**Manual Verification:**

1. Go to [ZKSync Era Sepolia Explorer](https://sepolia.explorer.zksync.io/)
2. Find your contract address
3. Click "Verify Contract"
4. Select "Solidity (Standard JSON Input)"
5. Upload the JSON from `out/` directory

**Automatic Verification (with forge):**

```bash
forge verify-contract <CONTRACT_ADDRESS> src/NFTStaking.sol:NFTStaking \
  --verifier etherscan \
  --verifier-url https://explorer.sepolia.era.zksync.dev/contract_verification \
  --rpc-url https://sepolia.era.zksync.dev \
  --etherscan-api-key IXC6WG7QKETAQB59T6B8XVMY31M4VPMNU9
```

## Network Configuration

| Parameter    | Value                               |
| ------------ | ----------------------------------- |
| Network Name | ZKSync Era Sepolia                  |
| RPC URL      | https://sepolia.era.zksync.dev      |
| Chain ID     | 300                                 |
| Currency     | ETH                                 |
| Explorer     | https://sepolia.explorer.zksync.io/ |

## Troubleshooting

### "Insufficient funds"

Get testnet ETH from the [ZKSync Faucet](https://portal.zksync.io/faucet)

### "Contract not verified"

Try manual verification through the block explorer UI

### "Transaction failed"

- Check gas limit
- Ensure you have enough ETH
- Verify contract addresses are correct

### "Lock period not ended"

For normal unstake, wait the full 7-day lock period or use `instantUnstake()` with penalty

## Post-Deployment Checklist

- [x] All contracts deployed successfully
- [x] Contracts verified on block explorer
- [x] MINTER_ROLE granted to staking contract
- [x] MockNFT collection whitelisted
- [ ] Demo transactions completed (run `DemoTransactions` script)
- [ ] Treasury receiving penalty fees confirmed (after demo transactions)

## Deployment Summary

**Deployment Date**: Successfully deployed and verified on ZKSync Era Sepolia testnet

**Total Gas Used**: 1,709,364 gas (0.0000427341 ETH at 0.025 gwei)

**All Contracts Verified**: ✅ All 3 contracts successfully verified on ZKSync Era Sepolia explorer

## Issues Encountered

1. **Issue**: Initial verification attempts defaulted to Sourcify instead of ZKSync explorer
   **Solution**: Added `--verifier etherscan` and `--etherscan-api-key` flags to explicitly use ZKSync verifier

2. **Issue**: Foundry verifier didn't recognize "zksync" as a valid verifier name
   **Solution**: Changed to `--verifier etherscan` which works with ZKSync's API endpoint

3. **Issue**: TOML syntax error with inline table newlines
   **Solution**: Fixed foundry.toml to use single-line inline table syntax

## Additional Notes

- The default reward rate is 1 token per second per NFT (1e18 wei)
- The default lock period is 7 days (604800 seconds)
- The default max penalty is 50% (5000 basis points)
- Treasury address receives all penalty fees as minted tokens
