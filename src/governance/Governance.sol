// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {ADMIN_ROLE, MEMBER_ROLE} from "src/dao_access/Roles.sol";
import {RoleControl} from "src/dao_access/RoleControl.sol";
import {Implementation} from "src/common/Implementation.sol";
import {LibMembers} from "src/common/LibMembers.sol";
import {LibGovernance} from "./LibGovernance.sol";

contract Governance is Implementation, RoleControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant MAX_THRESHOLD = 10000;

    enum ProposalStatus {
        UNKNOWN,
        PENDING,
        ONGOING,
        VOTED,
        READY,
        CANCELLED,
        FULFILLED
    }

    function bootstrap() external onlyRole(ADMIN_ROLE) {
        LibGovernance.StandardVoteParameters storage parameters = _data()
            .standardVoteParameters;

        parameters.minVotingPeriod = 1 days;
        parameters.maxVotingPeriod = 31 days;
        // parameters.minGracePeriod = 0;
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

        proposal.cancelled = true;
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
                // need try/catch
                // error handling??
                (bool success, bytes memory result) = address(this).call(
                    proposal.datas[i]
                );

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

    function _proposalStatus(
        uint256 proposalId
    ) internal view returns (ProposalStatus) {
        uint256 nbOfMembers = _members().members.length();
        LibGovernance.Proposal storage proposal = _data().proposals[proposalId];
        uint256 timestamp = block.timestamp;

        // exist?
        if (!proposal.active) return ProposalStatus.UNKNOWN;

        // cancelled?
        if (proposal.cancelled) return ProposalStatus.CANCELLED;

        // fulfilled?
        if (proposal.proceeded) return ProposalStatus.FULFILLED;

        // started?
        if (timestamp < proposal.startAt) return ProposalStatus.PENDING;

        // fully accepted (m/m => n/m?)
        if (proposal.nbYes == nbOfMembers) return ProposalStatus.READY;

        // vote period ended
        if (timestamp < proposal.endAt) return ProposalStatus.VOTED;

        // vote period ended
        if (timestamp < proposal.endAt + proposal.gracePeriod)
            return ProposalStatus.READY;

        // so far so good
        return ProposalStatus.ONGOING;
    }

    function _voteResult(
        LibGovernance.Proposal storage proposal
    ) internal view returns (bool) {
        // extract in memory
        return
            ((proposal.nbYes * 10000) / proposal.nbNo + proposal.nbYes) >=
            proposal.threshold;
    }

    function _data() internal pure returns (LibGovernance.Data storage) {
        return LibGovernance.accessData();
    }

    function _members() internal pure returns (LibMembers.Data storage) {
        return LibMembers.accessData();
    }
}
