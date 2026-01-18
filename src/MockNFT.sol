// SPDX-License-Identifier: MIT // change
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockNFT
 * @notice Simple ERC721 for testing the staking protocol
 */
contract MockNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {}

    function mint(address to) external returns (uint256 tokenId) {
        // @audit anyone can mint
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    function batchMint(
        address to,
        uint256 amount
    ) external returns (uint256 startId) {
        startId = _nextTokenId;
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, _nextTokenId++);
        }
    }

    // ---------------------------------------------------------
    // 💀 THE TRAP FOR MYTHRIL (Vulnerability Injection)
    // ---------------------------------------------------------

    // 1. We allow the contract to receive ETH (so there is something to steal)
    receive() external payable {}

    /**
     * @dev 🚨 VULNERABILITY: Unprotected Withdraw
     * Mythril will mathematically prove that ANYONE can call this
     * and drain the contract's balance.
     * It is missing the `onlyOwner` modifier.
     */
    function bug_test_withdraw() external {
        // SWC-105: Unprotected Ether Withdrawal
        payable(msg.sender).transfer(address(this).balance);
    }
}
