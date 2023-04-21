// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library LibGovernance {
    struct Proposal {
        // --- status ---
        bool active;
        bool proceeded;
        bool cancelled;
        // --- timing ---
        uint48 startAt;
        uint48 endAt;
        uint48 gracePeriod;
        // --- vote parameters ---
        uint16 threshold; // 0 ~ 10000
        // --- result ---
        uint256 nbYes;
        uint256 nbNo;
        uint256 nbNota;
        uint256 membersVoted;
        // --- vote info ---
        address proposer;
        mapping(address => bool) hasVote;
        // --- content ---
        bytes[] datas;
    }

    struct StandardVoteParameters {
        uint48 minVotingPeriod; // assuming the validation period is included
        uint48 maxVotingPeriod;
        uint48 minGracePeriod;
        uint48 maxGracePeriod;
        uint16 minThreshold;
    }

    struct Data {
        mapping(uint256 => Proposal) proposals;
        uint256 lastProposalId;
        StandardVoteParameters standardVoteParameters;
    }

    event Voted(uint256 indexed proposalId, address indexed voter);
    event Proposed(uint256 indexed proposalId, address indexed proposer);
    event Amended(uint256 proposalId, address indexed operator);

    error OutOfVotingPeriodLimit();
    error OutOfGracePeriodLimit();
    error OutOfThresholdLimit();
    error NotAnActiveProposal(uint256 proposalId);
    error OutOfVotingPeriod(uint256 proposalId);
    error OutOfGracePeriod(uint256 proposalId);
    error NotReadyToExecute(uint256 proposalId);
    error UnknownDescision();
    error ProposalAlreadyVoted(uint256 proposalId);

    /// @dev Storage slot for Data struct
    bytes32 internal constant STORAGE_SLOT =
        keccak256("terrabiodao.contracts.storage.Governance.v1");

    /// @return data Data struct at `STORAGE_SLOT`
    function accessData() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }

    function claimProposalId() internal returns (uint256) {
        unchecked {
            return ++accessData().lastProposalId;
        }
    }
}
