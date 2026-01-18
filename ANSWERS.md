# Technical Design Answers

## 1. Penalty Calculation

### Formula Implementation

The penalty is calculated using a linear decay formula:

```solidity
function _calculatePenaltyPercent(uint256 stakedAt) internal view returns (uint256 penaltyBps) {
    uint256 timeStaked = block.timestamp - stakedAt;

    // No penalty after lock period
    if (timeStaked >= lockPeriod) return 0;

    // Linear decrease: penalty = maxPenalty * (lockPeriod - timeStaked) / lockPeriod
    uint256 remaining = lockPeriod - timeStaked;
    return (maxPenalty * remaining) / lockPeriod;
}
```

### Precision Handling

**Basis Points (BPS)**: All percentages use basis points where 10000 = 100%. This provides:

- 0.01% precision without floating point
- Integer-only arithmetic (no rounding errors)
- Gas-efficient calculations

**Example calculations:**

```
Day 0: penalty = 5000 * 604800 / 604800 = 5000 (50%)
Day 3.5: penalty = 5000 * 302400 / 604800 = 2500 (25%)
Day 7: penalty = 5000 * 0 / 604800 = 0 (0%)
```

**Order of Operations**: Multiplication before division to minimize precision loss:

```solidity
// Good: (maxPenalty * remaining) / lockPeriod
// Bad: maxPenalty * (remaining / lockPeriod) -- loses precision
```

---

## 2. Multi-NFT Management

### Data Structures

```solidity
// Core stake tracking: collection -> tokenId -> StakeInfo
mapping(address => mapping(uint256 => StakeInfo)) public stakes;

// User's staked tokens: user -> collection -> tokenIds[]
mapping(address => mapping(address => uint256[])) private _userStakedTokens;

// Token index for O(1) removal: collection -> tokenId -> array index
mapping(address => mapping(uint256 => uint256)) private _tokenIndex;
```

### Why This Design?

1. **Double Mapping for Stakes**:

   - O(1) lookup by collection + tokenId
   - Supports multiple collections naturally
   - Each NFT is independently tracked

2. **Array for User Tokens**:

   - Enables enumeration of user's staked NFTs
   - Required for UI/frontend display
   - O(1) access by index

3. **Index Mapping**:
   - Enables O(1) removal from array
   - Swap-and-pop pattern avoids O(n) shifts
   - Gas-efficient for frequent unstaking

### Removal Pattern

```solidity
function _removeStake(address collection, uint256 tokenId, address user) internal {
    uint256[] storage userTokens = _userStakedTokens[user][collection];
    uint256 index = _tokenIndex[collection][tokenId];
    uint256 lastIndex = userTokens.length - 1;

    // Swap with last element and pop
    if (index != lastIndex) {
        uint256 lastTokenId = userTokens[lastIndex];
        userTokens[index] = lastTokenId;
        _tokenIndex[collection][lastTokenId] = index;
    }
    userTokens.pop();
    delete _tokenIndex[collection][tokenId];
}
```

---

## 3. Edge Cases Handled

### 1. Zero Rewards (Immediate Unstake)

```solidity
// User stakes and unstakes in same block
if (userRewards > 0) {
    rewardToken.mint(msg.sender, userRewards);
}
// No mint if rewards are 0 - prevents unnecessary transaction
```

### 2. Unstaking Non-Existent NFT

```solidity
if (stakeInfo.staker == address(0)) revert NFTNotStaked(collection, tokenId);
// Clear error message, no state changes
```

### 3. Double Staking Same NFT

- First stake transfers NFT to contract
- Second attempt fails at ERC721 level (user doesn't own it)
- No custom handling needed, ERC721 reverts naturally

### 4. Claiming After Full Unstake

```solidity
if (stakeInfo.staker == address(0)) revert NFTNotStaked(collection, tokenId);
// Stake info is deleted on unstake, so this catches attempts to claim
```

### 5. Lock Period Boundary

```solidity
if (timeStaked >= lockPeriod) return 0;
// >= ensures exactly at 7 days gets 0 penalty
```

### 6. Direct NFT Transfer to Contract

```solidity
// NFT transferred directly (not through stake()) won't be tracked
// Contract accepts it (onERC721Received) but creates no stake record
// NFT is recoverable by admin if needed
```

### 7. Reward Rate Change Mid-Stake

- New rate applies to future rewards only
- Historical rewards calculated with old rate up to claim time
- No retroactive changes

---

## 4. Gas Optimization

### Optimizations Implemented

1. **Unchecked Blocks for Loop Counters**

```solidity
for (uint256 i = 0; i < length;) {
    // ... loop body ...
    unchecked { ++i; }
}
// Saves ~60 gas per iteration (overflow check skip)
```

2. **Storage Caching**

```solidity
uint256 length = tokenIds.length;  // Cache array length
StakeInfo storage stakeInfo = stakes[collection][tokenId];  // Single SLOAD
```

3. **Swap-and-Pop Array Removal**

```solidity
// O(1) removal instead of O(n) shift
userTokens[index] = userTokens[lastIndex];
userTokens.pop();
```

4. **Batch Operations**

```solidity
function batchStake(address collection, uint256[] calldata tokenIds)
function batchClaimRewards(address collection, uint256[] calldata tokenIds)
// Reduces per-transaction overhead
```

5. **Minimal Storage Writes**

- Only write what changes
- Delete unused mappings to get gas refund

### Gas Measurements

| Operation                       | Gas Cost |
| ------------------------------- | -------- |
| stake()                         | ~215,000 |
| unstake() (after lock)          | ~276,000 |
| instantUnstake() (with penalty) | ~320,000 |
| claimRewards()                  | ~275,000 |
| batchStake(3 NFTs)              | ~520,000 |

---

## 5. Security Considerations

### Vulnerabilities Considered

1. **Reentrancy**

   - **Risk**: NFT callbacks during transfer could re-enter contract
   - **Prevention**: `ReentrancyGuard` on all state-changing functions
   - **Pattern**: Checks-Effects-Interactions (state updates before external calls)

2. **Access Control**

   - **Risk**: Unauthorized admin actions
   - **Prevention**: `Ownable2Step` for owner functions, `AccessControl` for minting
   - **Pattern**: Two-step ownership transfer prevents accidental loss

3. **Integer Overflow/Underflow**

   - **Risk**: Arithmetic errors in calculations
   - **Prevention**: Solidity 0.8+ automatic checks, explicit unchecked only where safe

4. **Front-Running**

   - **Risk**: Admin changes rates before user transactions
   - **Mitigation**: Users can check current rates before transacting
   - **Note**: Not critical for this use case (no slippage-sensitive swaps)

5. **Denial of Service**

   - **Risk**: Blocking user withdrawals
   - **Prevention**: No external calls in loops that could fail
   - **Pattern**: Pull over push for rewards

6. **Unauthorized Minting**
   - **Risk**: Infinite token supply
   - **Prevention**: Only staking contract has MINTER_ROLE

### Security Patterns Used

```solidity
// ReentrancyGuard
function stake(...) external nonReentrant { ... }

// Checks-Effects-Interactions
function unstake(...) {
    // 1. Checks
    if (stakeInfo.staker != msg.sender) revert NotStaker();

    // 2. Effects (state changes)
    _removeStake(...);

    // 3. Interactions (external calls)
    rewardToken.mint(...);
    IERC721(collection).safeTransferFrom(...);
}
```

---

## 6. Admin Changes Impact on Existing Stakes

### Reward Rate Changes

- **Effect**: Applies to all future rewards immediately
- **Existing Stakes**: Continue earning at new rate from change timestamp
- **Claimed Rewards**: Unaffected (already minted)
- **Rationale**: Simpler implementation, fair to all stakers equally

### Lock Period Changes

- **Effect**: Applies to existing stakes immediately
- **Example**: If reduced from 7 to 3 days, users staked for 4+ days can now unstake
- **Rationale**: Admin flexibility for emergency situations

### Penalty Rate Changes

- **Effect**: Applies to existing stakes immediately
- **Example**: If increased from 50% to 80%, all current stakers face higher penalty
- **Rationale**: Allows protocol to adjust incentives

### Design Decision

We chose **immediate application** over **grandfathered rates** because:

1. Simpler implementation (no per-stake rate storage)
2. Lower gas costs (no additional storage reads)
3. Admin flexibility for protocol adjustments
4. Users can check current parameters before transacting

---

## 7. Trade-offs

### Biggest Trade-off: Immediate vs Grandfathered Rate Changes

**Current Design**: Rate changes apply immediately to all stakes

**Pros:**

- Simpler, gas-efficient implementation
- No additional storage per stake
- Admin has full control over protocol economics

**Cons:**

- Users can be surprised by rate changes
- Less predictable returns for long-term stakers
- Potential trust issues if rates change frequently

### What I Would Do Differently

**With More Time:**

1. **Snapshot Rates at Stake Time**

   ```solidity
   struct StakeInfo {
       address staker;
       uint256 stakedAt;
       uint256 lastClaimTime;
       uint256 rateAtStake;      // ADD: Lock in reward rate
       uint256 penaltyAtStake;   // ADD: Lock in penalty rate
       uint256 lockPeriodAtStake; // ADD: Lock in lock period
   }
   ```

   - Guarantees predictable returns
   - More gas but better UX

2. **Governance/Timelock for Admin Changes**

   - 24-48 hour delay on parameter changes
   - Users can react to upcoming changes
   - More decentralized

3. **Emergency Unstake Function**

   - Allow instant unstake with 100% penalty in emergencies
   - Protocol safety valve

4. **Reward Accumulator Pattern**

   - Pre-calculate rewards per share like MasterChef
   - More gas-efficient for many stakers

5. **NFT Metadata Integration**
   - Different reward rates based on NFT rarity
   - Requires oracle or on-chain rarity data

### Current Trade-off Justification

For this implementation, immediate rate application was chosen because:

1. It matches the spec requirements without over-engineering
2. It's the standard pattern in most staking protocols
3. The target is testnet demonstration, not production
4. Complexity can be added later if needed
