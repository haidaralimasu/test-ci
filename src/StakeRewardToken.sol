// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title StakeRewardToken
 * @notice ERC20 token used as rewards for NFT staking
 * @dev Includes a MINTER_ROLE that allows the staking contract to mint rewards
 */
contract StakeRewardToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @notice Constructor sets up the token with name, symbol, and grants admin role
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param admin Address to receive DEFAULT_ADMIN_ROLE
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address admin
    ) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Mint tokens to a recipient
     * @dev Only callable by addresses with MINTER_ROLE
     * @param to Recipient address
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
