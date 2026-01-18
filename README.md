# NFT Staking Protocol with Time-Based Penalties

A comprehensive NFT staking protocol that allows users to stake ERC721 NFTs to earn ERC20 token rewards, featuring a time-based penalty system for early unstaking.

## Overview

This protocol enables NFT holders to:

- Stake NFTs from whitelisted collections
- Earn rewards based on staking duration
- Claim rewards without unstaking
- Unstake with or without penalties depending on lock period

### Key Features

- **Multi-Collection Support**: Admin can whitelist multiple NFT collections
- **Per-NFT Tracking**: Each NFT has independent lock period and reward tracking
- **Linear Penalty Decay**: 50% penalty at day 0, decreasing to 0% at day 7
- **Flexible Unstaking**: Choose between instant unstake (with penalty) or wait for penalty-free withdrawal
- **Reward Claiming**: Claim accumulated rewards anytime without affecting lock period

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      NFTStaking.sol                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Staking       │  │   Rewards       │  │  Penalties  │ │
│  │   - stake()     │  │   - claim()     │  │  - instant  │ │
│  │   - unstake()   │  │   - pending()   │  │  - treasury │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │                      │                    │
         ▼                      ▼                    ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   ERC721 NFTs   │   │ StakeRewardToken│   │    Treasury     │
│  (Whitelisted)  │   │    (ERC20)      │   │   (Penalties)   │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

## Penalty System

The penalty system uses a linear decay formula:

```
penalty% = maxPenalty × (lockPeriod - timeStaked) / lockPeriod
```

| Time Staked | Penalty |
| ----------- | ------- |
| 0 days      | 50%     |
| 1 day       | ~43%    |
| 3.5 days    | 25%     |
| 7 days      | 0%      |
| 7+ days     | 0%      |

**Precision**: Uses basis points (10000 = 100%) for precise calculations without floating point errors.

## Contracts

| Contract               | Description                                            |
| ---------------------- | ------------------------------------------------------ |
| `NFTStaking.sol`       | Main staking logic, rewards, penalties, admin controls |
| `StakeRewardToken.sol` | ERC20 reward token with minter role                    |
| `MockNFT.sol`          | Test ERC721 for development and testing                |

## Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd NFT-Stake

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

## Usage

### Staking an NFT

```solidity
// 1. Approve the staking contract
nft.approve(address(staking), tokenId);

// 2. Stake the NFT
staking.stake(address(nft), tokenId);
```

### Claiming Rewards

```solidity
// Claim without unstaking (does NOT reset lock period)
staking.claimRewards(address(nft), tokenId);
```

### Unstaking

```solidity
// Option 1: Wait for lock period (no penalty)
staking.unstake(address(nft), tokenId);

// Option 2: Instant unstake (pays penalty if within lock period)
staking.instantUnstake(address(nft), tokenId);
```

### View Functions

```solidity
// Check pending rewards
uint256 rewards = staking.pendingRewards(address(nft), tokenId);

// Check current penalty percentage
uint256 penaltyBps = staking.currentPenalty(address(nft), tokenId);

// Check remaining lock time
uint256 remaining = staking.lockTimeRemaining(address(nft), tokenId);

// Get user's staked tokens
uint256[] memory tokens = staking.getUserStakedTokens(user, address(nft));
```

## Admin Functions

| Function                    | Description                           |
| --------------------------- | ------------------------------------- |
| `addCollection(address)`    | Whitelist an NFT collection           |
| `removeCollection(address)` | Remove collection from whitelist      |
| `setRewardRate(uint256)`    | Set reward rate (tokens/second/NFT)   |
| `setLockPeriod(uint256)`    | Set lock period duration              |
| `setMaxPenalty(uint256)`    | Set maximum penalty (in basis points) |
| `setTreasury(address)`      | Set treasury address for penalties    |

## Testing

Run the comprehensive test suite:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_InstantUnstake_Day3_5_25Percent_Penalty -vvv

# Run with gas reporting
forge test --gas-report
```

### Test Coverage

- Basic staking and unstaking
- Reward accumulation over time
- Penalty calculations at various intervals
- Multiple NFTs with different stake times
- Edge cases (zero rewards, immediate unstake)
- Access control
- Security scenarios

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy (ZKSync Era Sepolia)

**Using Foundry account (recommended):**

```bash
# Add account to Foundry (if not already added)
cast wallet import deployer --interactive

# Deploy
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://sepolia.era.zksync.dev \
  --account deployer \
  --broadcast \
  --verify
```

**Or using private key directly:**

```bash
# Deploy
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://sepolia.era.zksync.dev \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## Security Considerations

- **ReentrancyGuard**: All external state-changing functions are protected
- **Ownable2Step**: Two-step ownership transfer prevents accidental transfers
- **Access Control**: Only token minter can mint rewards
- **Input Validation**: All admin functions validate inputs
- **Safe Transfers**: Uses safeTransferFrom for NFT transfers

## Gas Optimizations

- Unchecked blocks for loop counters
- Storage variable caching in local variables
- Efficient array removal (swap and pop)
- Minimal storage writes
- Events for off-chain indexing

## License

MIT
