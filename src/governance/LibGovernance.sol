// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library LibGovernance {
    /// @dev Split into structs?
    struct Proposal {
        // --- status ---
        bool active;
        bool proceeded;
        bool canceled;
        // --- timing ---
        uint48 startAt;
        uint48 endAt;
        // --- content ---
        bytes[] datas;
        // --- info ---
        address proposer;
        // --- vote parameters ---
        uint32 threshold;
        uint48 gracePeriod;
        // --- vote ---
        mapping(address => bool) hasVote;
        // --- result ---
        uint256 nbYes;
        uint256 nbNo;
        uint256 nbNota;
        uint256 membersVoted;
    }
}
