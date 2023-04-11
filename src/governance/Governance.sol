// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {ADMIN_ROLE, MEMBER_ROLE} from "src/dao_access/Roles.sol";
import {RoleControl} from "src/dao_access/RoleControl.sol";
import {Implementation} from "src/common/Implementation.sol";

import {LibGovernance} from "./LibGovernance.sol";

contract Governance is Implementation, RoleControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function bootstrap() external onlyRole(ADMIN_ROLE) {
        LibGovernance.StandardVoteParameters storage parameters = _data()
            .standardVoteParameters;

        parameters.minVotingPeriod = 1 days;
        parameters.maxVotingPeriod = 31 days;
        parameters.minGracePeriod = 1 days;
        parameters.maxGracePeriod = 7 days;
        parameters.minThreshold = 8000; // 80%
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function vote(
        uint256 proposalId,
        uint256 descision
    ) external onlyRole(MEMBER_ROLE) {
        LibGovernance.Proposal storage proposal = _data().proposals[proposalId];
        if (!proposal.active)
            revert LibGovernance.NotAnActiveProposal(proposalId);

        uint256 timestamp = block.timestamp;
        if (timestamp < proposal.startAt || timestamp > proposal.endAt)
            revert LibGovernance.OutOfVotingPeriod(proposalId);

        bool hasVote = proposal.hasVote[msg.sender];
        if (hasVote) revert LibGovernance.ProposalAlreadyVoted(proposalId);
        proposal.hasVote[msg.sender] = true;

        if (descision == 0) {
            proposal.nbNo++;
        } else if (descision == 1) {
            proposal.nbYes++;
        } else if (descision == 2) {
            proposal.nbNota++;
        } else {
            revert LibGovernance.UnknownDescision();
        }
        proposal.membersVoted++;

        emit LibGovernance.Voted(proposalId, msg.sender);
    }

    function propose(
        uint48 startAt,
        uint48 votingPeriod,
        uint48 gracePeriod,
        uint16 threshold,
        bytes[] memory datas
    ) external onlyRole(MEMBER_ROLE) {
        LibGovernance.Data storage data = _data();

        // check proposition parameters
        if (
            startAt < block.timestamp ||
            votingPeriod < data.standardVoteParameters.minVotingPeriod ||
            votingPeriod > data.standardVoteParameters.maxVotingPeriod
        ) revert LibGovernance.OutOfVotingPeriodLimit();

        if (
            gracePeriod < data.standardVoteParameters.minGracePeriod ||
            gracePeriod > data.standardVoteParameters.maxGracePeriod
        ) revert LibGovernance.OutOfGracePeriodLimit();

        if (
            threshold < data.standardVoteParameters.minThreshold ||
            threshold > 10000
        ) revert LibGovernance.OutOfThresholdLimit();

        // store proposition
        uint256 proposalId = LibGovernance.claimProposalId();
        LibGovernance.Proposal storage proposal = data.proposals[proposalId];
        proposal.active = true;
        proposal.startAt = startAt;
        proposal.endAt = startAt + votingPeriod;
        proposal.datas = datas;
        proposal.proposer = msg.sender;
        proposal.gracePeriod = gracePeriod;
        proposal.threshold = threshold;

        emit LibGovernance.Proposed(proposalId, msg.sender);
    }

    function cancelProposal(uint256 proposalId) external onlyRole(ADMIN_ROLE) {
        LibGovernance.Proposal storage proposal = _data().proposals[proposalId];
        if (!proposal.active)
            revert LibGovernance.NotAnActiveProposal(proposalId);

        if (block.timestamp > proposal.endAt + proposal.gracePeriod)
            revert LibGovernance.OutOfGracePeriod(proposalId);

        proposal.canceled = true;
        emit LibGovernance.Amended(proposalId, msg.sender);
    }

    function execute(uint256 proposalId) external {
        LibGovernance.Proposal storage proposal = _data().proposals[proposalId];
        if (!proposal.active)
            revert LibGovernance.NotAnActiveProposal(proposalId);

        if (block.timestamp < proposal.endAt + proposal.gracePeriod)
            revert LibGovernance.NotReadyToExecute(proposalId);

        if (_voteResult(proposal)) {
            uint256 nbOfCalls = proposal.datas.length;
            for (uint256 i; i < nbOfCalls; ) {
                // call on (this) = call to self
                (bool success, bytes memory result) = address(this).call(
                    proposal.datas[i]
                );

                // error handling??
                if (!success) proposal.datas[i] = result; // report in datas or elsewhere?

                unchecked {
                    i++;
                }
            }
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _voteResult(
        LibGovernance.Proposal storage proposal
    ) internal view returns (bool) {
        return ((proposal.nbYes * 10000) / proposal.nbNo) >= proposal.threshold;
    }

    function _data() internal pure returns (LibGovernance.Data storage) {
        return LibGovernance.accessData();
    }
}
