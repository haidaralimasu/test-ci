// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./StakeRewardToken.sol";

/**
 * @title NFTStaking
 * @notice NFT staking protocol with time-based penalties and ERC20 rewards
 * @dev Supports multiple whitelisted NFT collections with independent lock periods per NFT
 * 
 * Key Features:
 * - Stake ERC721 NFTs to earn ERC20 token rewards
 * - 7-day lock period with linear penalty decrease (50% -> 0%)
 * - Instant unstake (pays penalty) vs normal unstake (no penalty after lock)
 * - Per-NFT reward tracking and lock periods
 * - Admin controls for rates, penalties, and collections
 */
contract NFTStaking is IERC721Receiver, Ownable2Step, ReentrancyGuard {
    // ============ Constants ============
    
    /// @notice Basis points denominator (100% = 10000)
    uint256 public constant BASIS_POINTS = 10000;
    
    /// @notice Default lock period: 7 days in seconds
    uint256 public constant DEFAULT_LOCK_PERIOD = 7 days;
    
    /// @notice Default max penalty: 50% in basis points
    uint256 public constant DEFAULT_MAX_PENALTY = 5000;
    
    /// @notice Default reward rate: 1 token per second per NFT (in wei)
    uint256 public constant DEFAULT_REWARD_RATE = 1e18;

    // ============ Structs ============
    
    /**
     * @notice Information about a staked NFT
     * @param staker Address that staked the NFT
     * @param stakedAt Timestamp when the NFT was staked
     * @param lastClaimTime Last time rewards were claimed for this NFT
     */
    struct StakeInfo {
        address staker;
        uint256 stakedAt;
        uint256 lastClaimTime;
    }

    // ============ State Variables ============
    
    /// @notice The ERC20 token used for rewards
    StakeRewardToken public immutable rewardToken;
    
    /// @notice Treasury address that receives penalty fees
    address public treasury;
    
    /// @notice Reward rate in tokens per second per staked NFT (in wei)
    uint256 public rewardRate;
    
    /// @notice Lock period duration in seconds
    uint256 public lockPeriod;
    
    /// @notice Maximum penalty percentage in basis points (5000 = 50%)
    uint256 public maxPenalty;
    
    /// @notice Total penalties accumulated in treasury
    uint256 public accumulatedPenalties;

    /// @notice Mapping: collection => tokenId => stake info
    mapping(address => mapping(uint256 => StakeInfo)) public stakes;
    
    /// @notice Mapping: user => collection => array of staked token IDs
    mapping(address => mapping(address => uint256[])) private _userStakedTokens;
    
    /// @notice Mapping: collection => tokenId => index in user's staked tokens array
    mapping(address => mapping(uint256 => uint256)) private _tokenIndex;
    
    /// @notice Mapping: collection address => is whitelisted
    mapping(address => bool) public whitelistedCollections;
    
    /// @notice Array of all whitelisted collections for enumeration
    address[] public collections;

    // ============ Events ============
    
    event Staked(address indexed user, address indexed collection, uint256 indexed tokenId, uint256 timestamp);
    event Unstaked(address indexed user, address indexed collection, uint256 indexed tokenId, uint256 rewards, uint256 penalty);
    event RewardsClaimed(address indexed user, address indexed collection, uint256 indexed tokenId, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event LockPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event MaxPenaltyUpdated(uint256 oldPenalty, uint256 newPenalty);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event CollectionAdded(address indexed collection);
    event CollectionRemoved(address indexed collection);
    event PenaltiesWithdrawn(address indexed to, uint256 amount);

    // ============ Errors ============
    
    error CollectionNotWhitelisted(address collection);
    error NotStaker(address caller, address staker);
    error NFTNotStaked(address collection, uint256 tokenId);
    error LockPeriodNotEnded(uint256 stakedAt, uint256 lockEndsAt);
    error InvalidAddress();
    error InvalidAmount();
    error CollectionAlreadyWhitelisted(address collection);
    error CollectionNotFound(address collection);
    error TransferFailed();

    // ============ Constructor ============
    
    /**
     * @notice Deploy the staking contract
     * @param _rewardToken Address of the ERC20 reward token
     * @param _treasury Address to receive penalty fees
     */
    constructor(
        address _rewardToken,
        address _treasury
    ) Ownable(msg.sender) {
        if (_rewardToken == address(0) || _treasury == address(0)) revert InvalidAddress();
        
        rewardToken = StakeRewardToken(_rewardToken);
        treasury = _treasury;
        rewardRate = DEFAULT_REWARD_RATE;
        lockPeriod = DEFAULT_LOCK_PERIOD;
        maxPenalty = DEFAULT_MAX_PENALTY;
    }

    // ============ External Functions ============
    
    /**
     * @notice Stake an NFT to start earning rewards
     * @param collection Address of the NFT collection
     * @param tokenId ID of the token to stake
     */
    function stake(address collection, uint256 tokenId) external nonReentrant {
        if (!whitelistedCollections[collection]) revert CollectionNotWhitelisted(collection);
        
        // Transfer NFT from user to this contract
        IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // Record stake info
        stakes[collection][tokenId] = StakeInfo({
            staker: msg.sender,
            stakedAt: block.timestamp,
            lastClaimTime: block.timestamp
        });
        
        // Add to user's staked tokens
        _tokenIndex[collection][tokenId] = _userStakedTokens[msg.sender][collection].length;
        _userStakedTokens[msg.sender][collection].push(tokenId);
        
        emit Staked(msg.sender, collection, tokenId, block.timestamp);
    }
    
    /**
     * @notice Stake multiple NFTs at once
     * @param collection Address of the NFT collection
     * @param tokenIds Array of token IDs to stake
     */
    function batchStake(address collection, uint256[] calldata tokenIds) external nonReentrant {
        if (!whitelistedCollections[collection]) revert CollectionNotWhitelisted(collection);
        
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];
            
            // Transfer NFT from user to this contract
            IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);
            
            // Record stake info
            stakes[collection][tokenId] = StakeInfo({
                staker: msg.sender,
                stakedAt: block.timestamp,
                lastClaimTime: block.timestamp
            });
            
            // Add to user's staked tokens
            _tokenIndex[collection][tokenId] = _userStakedTokens[msg.sender][collection].length;
            _userStakedTokens[msg.sender][collection].push(tokenId);
            
            emit Staked(msg.sender, collection, tokenId, block.timestamp);
            
            unchecked { ++i; }
        }
    }
    
    /**
     * @notice Unstake an NFT after the lock period has ended (no penalty)
     * @param collection Address of the NFT collection
     * @param tokenId ID of the token to unstake
     */
    function unstake(address collection, uint256 tokenId) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        
        if (stakeInfo.staker == address(0)) revert NFTNotStaked(collection, tokenId);
        if (stakeInfo.staker != msg.sender) revert NotStaker(msg.sender, stakeInfo.staker);
        
        uint256 lockEndsAt = stakeInfo.stakedAt + lockPeriod;
        if (block.timestamp < lockEndsAt) revert LockPeriodNotEnded(stakeInfo.stakedAt, lockEndsAt);
        
        // Calculate and mint rewards (no penalty)
        uint256 rewards = _calculateRewards(collection, tokenId);
        
        // Clean up stake
        _removeStake(collection, tokenId, msg.sender);
        
        // Mint full rewards to user
        if (rewards > 0) {
            rewardToken.mint(msg.sender, rewards);
        }
        
        // Transfer NFT back to user
        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit Unstaked(msg.sender, collection, tokenId, rewards, 0);
    }
    
    /**
     * @notice Instantly unstake an NFT (may incur penalty if within lock period)
     * @param collection Address of the NFT collection
     * @param tokenId ID of the token to unstake
     */
    function instantUnstake(address collection, uint256 tokenId) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        
        if (stakeInfo.staker == address(0)) revert NFTNotStaked(collection, tokenId);
        if (stakeInfo.staker != msg.sender) revert NotStaker(msg.sender, stakeInfo.staker);
        
        // Calculate rewards
        uint256 rewards = _calculateRewards(collection, tokenId);
        
        // Calculate penalty
        uint256 penalty = _calculatePenalty(stakeInfo.stakedAt, rewards);
        uint256 userRewards = rewards - penalty;
        
        // Clean up stake
        _removeStake(collection, tokenId, msg.sender);
        
        // Mint rewards to user (minus penalty)
        if (userRewards > 0) {
            rewardToken.mint(msg.sender, userRewards);
        }
        
        // Mint penalty to treasury
        if (penalty > 0) {
            rewardToken.mint(treasury, penalty);
            accumulatedPenalties += penalty;
        }
        
        // Transfer NFT back to user
        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit Unstaked(msg.sender, collection, tokenId, userRewards, penalty);
    }
    
    /**
     * @notice Claim accumulated rewards without unstaking
     * @param collection Address of the NFT collection
     * @param tokenId ID of the staked token
     */
    function claimRewards(address collection, uint256 tokenId) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        
        if (stakeInfo.staker == address(0)) revert NFTNotStaked(collection, tokenId);
        if (stakeInfo.staker != msg.sender) revert NotStaker(msg.sender, stakeInfo.staker);
        
        uint256 rewards = _calculateRewards(collection, tokenId);
        
        // Update last claim time (does NOT reset lock period)
        stakeInfo.lastClaimTime = block.timestamp;
        
        // Mint rewards to user
        if (rewards > 0) {
            rewardToken.mint(msg.sender, rewards);
        }
        
        emit RewardsClaimed(msg.sender, collection, tokenId, rewards);
    }
    
    /**
     * @notice Claim rewards for multiple staked NFTs
     * @param collection Address of the NFT collection
     * @param tokenIds Array of token IDs to claim rewards for
     */
    function batchClaimRewards(address collection, uint256[] calldata tokenIds) external nonReentrant {
        uint256 totalRewards = 0;
        uint256 length = tokenIds.length;
        
        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];
            StakeInfo storage stakeInfo = stakes[collection][tokenId];
            
            if (stakeInfo.staker == address(0)) revert NFTNotStaked(collection, tokenId);
            if (stakeInfo.staker != msg.sender) revert NotStaker(msg.sender, stakeInfo.staker);
            
            uint256 rewards = _calculateRewards(collection, tokenId);
            stakeInfo.lastClaimTime = block.timestamp;
            totalRewards += rewards;
            
            emit RewardsClaimed(msg.sender, collection, tokenId, rewards);
            
            unchecked { ++i; }
        }
        
        if (totalRewards > 0) {
            rewardToken.mint(msg.sender, totalRewards);
        }
    }

    // ============ View Functions ============
    
    /**
     * @notice Get pending rewards for a staked NFT
     * @param collection Address of the NFT collection
     * @param tokenId ID of the staked token
     * @return rewards Amount of pending rewards
     */
    function pendingRewards(address collection, uint256 tokenId) external view returns (uint256 rewards) {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        if (stakeInfo.staker == address(0)) return 0;
        
        return _calculateRewards(collection, tokenId);
    }
    
    /**
     * @notice Get the current penalty percentage for a staked NFT
     * @param collection Address of the NFT collection
     * @param tokenId ID of the staked token
     * @return penaltyBps Current penalty in basis points
     */
    function currentPenalty(address collection, uint256 tokenId) external view returns (uint256 penaltyBps) {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        if (stakeInfo.staker == address(0)) return 0;
        
        return _calculatePenaltyPercent(stakeInfo.stakedAt);
    }
    
    /**
     * @notice Get all staked token IDs for a user in a collection
     * @param user Address of the staker
     * @param collection Address of the NFT collection
     * @return tokenIds Array of staked token IDs
     */
    function getUserStakedTokens(address user, address collection) external view returns (uint256[] memory) {
        return _userStakedTokens[user][collection];
    }
    
    /**
     * @notice Get the number of whitelisted collections
     * @return count Number of collections
     */
    function getCollectionsCount() external view returns (uint256) {
        return collections.length;
    }
    
    /**
     * @notice Check if an NFT is currently staked
     * @param collection Address of the NFT collection
     * @param tokenId ID of the token
     * @return isStaked True if the NFT is staked
     */
    function isStaked(address collection, uint256 tokenId) external view returns (bool) {
        return stakes[collection][tokenId].staker != address(0);
    }
    
    /**
     * @notice Get time remaining until lock period ends for a staked NFT
     * @param collection Address of the NFT collection
     * @param tokenId ID of the staked token
     * @return remaining Seconds remaining (0 if lock period ended)
     */
    function lockTimeRemaining(address collection, uint256 tokenId) external view returns (uint256 remaining) {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        if (stakeInfo.staker == address(0)) return 0;
        
        uint256 lockEndsAt = stakeInfo.stakedAt + lockPeriod;
        if (block.timestamp >= lockEndsAt) return 0;
        
        return lockEndsAt - block.timestamp;
    }

    // ============ Admin Functions ============
    
    /**
     * @notice Add a collection to the whitelist
     * @param collection Address of the NFT collection to add
     */
    function addCollection(address collection) external onlyOwner {
        if (collection == address(0)) revert InvalidAddress();
        if (whitelistedCollections[collection]) revert CollectionAlreadyWhitelisted(collection);
        
        whitelistedCollections[collection] = true;
        collections.push(collection);
        
        emit CollectionAdded(collection);
    }
    
    /**
     * @notice Remove a collection from the whitelist
     * @param collection Address of the NFT collection to remove
     */
    function removeCollection(address collection) external onlyOwner {
        if (!whitelistedCollections[collection]) revert CollectionNotFound(collection);
        
        whitelistedCollections[collection] = false;
        
        // Remove from array
        uint256 length = collections.length;
        for (uint256 i = 0; i < length;) {
            if (collections[i] == collection) {
                collections[i] = collections[length - 1];
                collections.pop();
                break;
            }
            unchecked { ++i; }
        }
        
        emit CollectionRemoved(collection);
    }
    
    /**
     * @notice Update the reward rate
     * @param newRate New reward rate in tokens per second per NFT (in wei)
     */
    function setRewardRate(uint256 newRate) external onlyOwner {
        emit RewardRateUpdated(rewardRate, newRate);
        rewardRate = newRate;
    }
    
    /**
     * @notice Update the lock period duration
     * @param newPeriod New lock period in seconds
     */
    function setLockPeriod(uint256 newPeriod) external onlyOwner {
        emit LockPeriodUpdated(lockPeriod, newPeriod);
        lockPeriod = newPeriod;
    }
    
    /**
     * @notice Update the maximum penalty percentage
     * @param newMaxPenalty New max penalty in basis points (max 10000)
     */
    function setMaxPenalty(uint256 newMaxPenalty) external onlyOwner {
        if (newMaxPenalty > BASIS_POINTS) revert InvalidAmount();
        emit MaxPenaltyUpdated(maxPenalty, newMaxPenalty);
        maxPenalty = newMaxPenalty;
    }
    
    /**
     * @notice Update the treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    // ============ Internal Functions ============
    
    /**
     * @notice Calculate pending rewards for a staked NFT
     * @param collection Address of the NFT collection
     * @param tokenId ID of the staked token
     * @return rewards Amount of pending rewards
     */
    function _calculateRewards(address collection, uint256 tokenId) internal view returns (uint256 rewards) {
        StakeInfo storage stakeInfo = stakes[collection][tokenId];
        uint256 stakedDuration = block.timestamp - stakeInfo.lastClaimTime;
        return stakedDuration * rewardRate;
    }
    
    /**
     * @notice Calculate the current penalty percentage based on stake time
     * @param stakedAt Timestamp when the NFT was staked
     * @return penaltyBps Penalty in basis points
     */
    function _calculatePenaltyPercent(uint256 stakedAt) internal view returns (uint256 penaltyBps) {
        uint256 timeStaked = block.timestamp - stakedAt;
        
        // No penalty after lock period
        if (timeStaked >= lockPeriod) return 0;
        
        // Linear decrease: penalty = maxPenalty * (lockPeriod - timeStaked) / lockPeriod
        uint256 remaining = lockPeriod - timeStaked;
        return (maxPenalty * remaining) / lockPeriod;
    }
    
    /**
     * @notice Calculate the penalty amount for given rewards
     * @param stakedAt Timestamp when the NFT was staked
     * @param rewards Total rewards to apply penalty to
     * @return penalty Amount of penalty
     */
    function _calculatePenalty(uint256 stakedAt, uint256 rewards) internal view returns (uint256 penalty) {
        uint256 penaltyBps = _calculatePenaltyPercent(stakedAt);
        return (rewards * penaltyBps) / BASIS_POINTS;
    }
    
    /**
     * @notice Remove stake info and update user's staked tokens array
     * @param collection Address of the NFT collection
     * @param tokenId ID of the token being unstaked
     * @param user Address of the staker
     */
    function _removeStake(address collection, uint256 tokenId, address user) internal {
        // Delete stake info
        delete stakes[collection][tokenId];
        
        // Remove from user's staked tokens array (swap and pop)
        uint256[] storage userTokens = _userStakedTokens[user][collection];
        uint256 index = _tokenIndex[collection][tokenId];
        uint256 lastIndex = userTokens.length - 1;
        
        if (index != lastIndex) {
            uint256 lastTokenId = userTokens[lastIndex];
            userTokens[index] = lastTokenId;
            _tokenIndex[collection][lastTokenId] = index;
        }
        
        userTokens.pop();
        delete _tokenIndex[collection][tokenId];
    }
    
    /**
     * @notice Handle receiving ERC721 tokens
     * @dev Required for safeTransferFrom to work
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

