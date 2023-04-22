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
        ProposalStatus status = _proposalStatus(proposalId);

        if (status != ProposalStatus.ONGOING)
            revert LibGovernance.OutOfVotingPeriod(proposalId);

        mapping(uint256 => mapping(address => bool)) storage votes = _data()
            .votes;

        bool hasVote = votes[proposalId][msg.sender]; //proposal.hasVote[msg.sender];
        if (hasVote) revert LibGovernance.ProposalAlreadyVoted(proposalId);
        votes[proposalId][msg.sender] = true;

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
        bytes[] memory calls
    ) external onlyRole(MEMBER_ROLE) returns (uint256 proposalId) {
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
        proposalId = LibGovernance.claimProposalId();
        LibGovernance.Proposal storage proposal = data.proposals[proposalId];
        proposal.active = true;
        proposal.startAt = startAt;
        proposal.endAt = startAt + votingPeriod;
        proposal.calls = calls;
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

    event ping(uint256);
    event byt(bytes);
    event log(address, bytes4, bytes);

    function execute(uint256 proposalId) external {
        LibGovernance.Proposal storage proposal = _data().proposals[proposalId];
        ProposalStatus status = _proposalStatus(proposalId);

        if (status != ProposalStatus.READY)
            revert LibGovernance.NotReadyToExecute(proposalId);

        if (_voteResult(proposal)) {
            uint256 nbOfCalls = proposal.calls.length;
            for (uint256 i; i < nbOfCalls; ) {
                (address target, bytes memory callData) = abi.decode(
                    proposal.calls[i],
                    (address, bytes)
                );

                // ---

                // call on (this) = call to self
                // need try/catch
                // error handling??
                (bool success, bytes memory result) = target.call(callData);
                // (bool success, bytes memory result) = address(this).call(
                //     proposal.datas[i]
                // );

                if (!success) proposal.results[i] = result; // report in datas or elsewhere?

                unchecked {
                    i++;
                }
            }
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function getProposalStatus(
        uint256 proposalId
    ) external view returns (ProposalStatus) {
        return _proposalStatus(proposalId);
    }

    function getProposal(
        uint256 proposalId
    ) external view returns (LibGovernance.Proposal memory) {
        return _data().proposals[proposalId];
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
        if (timestamp > proposal.endAt + proposal.gracePeriod)
            return ProposalStatus.READY;

        // vote period ended
        if (timestamp > proposal.endAt) return ProposalStatus.VOTED;

        // so far so good
        return ProposalStatus.ONGOING;
    }

    function _voteResult(
        LibGovernance.Proposal storage proposal
    ) internal view returns (bool) {
        // extract in memory
        return
            ((proposal.nbYes * 10000) / (proposal.nbNo + proposal.nbYes)) >=
            proposal.threshold;
    }

    function _data() internal pure returns (LibGovernance.Data storage) {
        return LibGovernance.accessData();
    }

    function _members() internal pure returns (LibMembers.Data storage) {
        return LibMembers.accessData();
    }
}
