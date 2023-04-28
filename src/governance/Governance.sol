// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { ADMIN_ROLE, MEMBER_ROLE } from "src/dao_access/Roles.sol";
import { RoleControl } from "src/dao_access/RoleControl.sol";
import { PauseControl } from "src/pausable/PauseControl.sol";
import { Implementation } from "src/common/Implementation.sol";
import { LibMembers } from "src/common/LibMembers.sol";
import { LibGovernance } from "./LibGovernance.sol";

/**
 * @title Manage votes, propositions and execution in the DAO
 * @dev This implementation is simple:
 *      - only one vote parameter (see {bootstrap})
 *      - act as a multi-sig when all members vote `yes`
 *      - any members can create a proposal
 *      - vote descisions are `no`, `yes`, `nota`
 */
contract Governance is Implementation, RoleControl, PauseControl {
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

    /// @dev set `StandardVoteParameters`, called by the DAO deployer
    function bootstrap() external onlyRole(ADMIN_ROLE) {
        LibGovernance.StandardVoteParameters storage parameters = _data().standardVoteParameters;

        parameters.minVotingPeriod = 1 days;
        parameters.maxVotingPeriod = 31 days;
        // parameters.minGracePeriod = 0;
        parameters.maxGracePeriod = 7 days;
        parameters.minThreshold = 8000; // 80%
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Vote on a proposal
     * @dev users can only vote during the voting period
     *
     * @param proposalId number of the proposal
     * @param descision 0 == `no` | 1 == `yes` | 2 == `nota`
     */
    function vote(
        uint256 proposalId,
        uint256 descision
    ) external onlyRole(MEMBER_ROLE) whenNotPaused {
        // read proposal status
        ProposalStatus status = _proposalStatus(proposalId);
        if (status != ProposalStatus.ONGOING) revert LibGovernance.OutOfVotingPeriod(proposalId);

        // get storage
        LibGovernance.Proposal storage proposal = _data().proposals[proposalId];
        mapping(uint256 => mapping(address => bool)) storage votes = _data().votes;

        bool hasVote = votes[proposalId][msg.sender];
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

    /**
     * @notice Create a proposition
     * @dev only members can create proposals, proposals content is
     * not checked on-chain, users should be aware on the proposal content,
     * either on its validity or its dangerousness.
     *
     * @param startAt time at which the voting period starts
     * @param votingPeriod duration of the voting period
     * @param gracePeriod duration of the grace period
     * @param threshold acceptation threshold
     * @param calls arrays of calls (see {execute} for the call format)
     * @return proposalId number of the proposal
     */
    function propose(
        uint48 startAt,
        uint48 votingPeriod,
        uint48 gracePeriod,
        uint16 threshold,
        bytes[] memory calls
    ) external onlyRole(MEMBER_ROLE) whenNotPaused returns (uint256 proposalId) {
        LibGovernance.Data storage data = _data();
        LibGovernance.StandardVoteParameters memory params = data.standardVoteParameters;

        // check proposition parameters
        if (startAt == 0) startAt = uint48(block.timestamp);
        if (
            startAt < block.timestamp ||
            votingPeriod < params.minVotingPeriod ||
            votingPeriod > params.maxVotingPeriod
        ) revert LibGovernance.OutOfVotingPeriodLimit();

        if (gracePeriod < params.minGracePeriod || gracePeriod > params.maxGracePeriod)
            revert LibGovernance.OutOfGracePeriodLimit();

        if (threshold < params.minThreshold || threshold > 10000)
            revert LibGovernance.OutOfThresholdLimit();

        // store proposition (NOTE try memory struct on gas usage)
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

    /**
     * @notice Cancel a proposal
     * @dev This function should be called before the grace period is
     * over. This function is restricted by a vote as well.
     *
     * @param proposalId number of the proposal
     */
    function cancelProposal(uint256 proposalId) external onlyRole(ADMIN_ROLE) whenNotPaused {
        ProposalStatus status = _proposalStatus(proposalId);

        if (status == ProposalStatus.UNKNOWN) {
            revert LibGovernance.NotAnActiveProposal(proposalId);
        }

        if (
            status != ProposalStatus.ONGOING ||
            status != ProposalStatus.PENDING ||
            status != ProposalStatus.VOTED
        ) {
            revert LibGovernance.OutOfCancellationPeriod(proposalId);
        }

        _data().proposals[proposalId].cancelled = true;
        emit LibGovernance.Amended(proposalId, msg.sender);
    }

    /**
     * @notice Execute calls contained into accepted proposal
     * @dev Anyone can call this function as it only possible
     * when a proposal is accepted.
     *
     * Call format:
     * ```solidity
     *  abi.encode(
     *      address(target)),
     *      abi.encodeWithSignature("sig(uint256)", 42)
     *  );
     * ```
     *
     * @param proposalId number of the proposal
     */
    function execute(uint256 proposalId) external whenNotPaused {
        LibGovernance.Proposal memory proposal = _data().proposals[proposalId];
        ProposalStatus status = _proposalStatus(proposalId);

        if (status != ProposalStatus.READY) revert LibGovernance.NotReadyToExecute(proposalId);

        if (_voteResult(proposal)) {
            uint256 nbOfCalls = proposal.calls.length;
            bytes[] memory results = new bytes[](nbOfCalls);
            for (uint256 i; i < nbOfCalls; ) {
                // decode proposal call
                (address target, bytes memory callData) = abi.decode(
                    proposal.calls[i],
                    (address, bytes)
                );

                // need try/catch + error handling
                (, bytes memory result) = target.call(callData);

                // everything is reported in `results`
                results[i] = result;

                unchecked {
                    i++;
                }
            }
            _data().proposals[proposalId].results = results;
            _data().proposals[proposalId].proceeded = true;
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @return ProposalStatus enum of the `proposalId`
    function getProposalStatus(uint256 proposalId) external view returns (ProposalStatus) {
        return _proposalStatus(proposalId);
    }

    /// @return Proposal struct of the `proposalId`
    function getProposal(uint256 proposalId) external view returns (LibGovernance.Proposal memory) {
        return _data().proposals[proposalId];
    }

    /// @return Array of Proposal struct
    function getAllProposals() external view returns (LibGovernance.Proposal[] memory) {
        LibGovernance.Proposal[] memory arr = new LibGovernance.Proposal[](_data().lastProposalId);

        for (uint256 i = 0; i < _data().lastProposalId; i++) {
            arr[i] = _data().proposals[i];
        }

        return arr;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _proposalStatus(uint256 proposalId) internal view returns (ProposalStatus) {
        uint256 nbOfMembers = _members().length();
        LibGovernance.Proposal memory proposal = _data().proposals[proposalId];
        uint256 timestamp = block.timestamp;

        // exist?
        if (!proposal.active) return ProposalStatus.UNKNOWN;

        // cancelled?
        if (proposal.cancelled) return ProposalStatus.CANCELLED;

        // fulfilled?
        if (proposal.proceeded) return ProposalStatus.FULFILLED;

        // started?
        if (timestamp < proposal.startAt) return ProposalStatus.PENDING;

        // fully accepted? (NOTE m/m => n/m?)
        if (proposal.nbYes == nbOfMembers) return ProposalStatus.READY;

        // vote period ended?
        if (timestamp > proposal.endAt + proposal.gracePeriod) return ProposalStatus.READY;

        // vote period ended?
        if (timestamp > proposal.endAt) return ProposalStatus.VOTED;

        // so far so good
        return ProposalStatus.ONGOING;
    }

    function _voteResult(LibGovernance.Proposal memory proposal) internal pure returns (bool) {
        // y / y+n >= threshold
        return ((proposal.nbYes * 10000) / (proposal.nbNo + proposal.nbYes)) >= proposal.threshold;
    }

    function _data() internal pure returns (LibGovernance.Data storage) {
        return LibGovernance.accessData();
    }

    function _members() internal view returns (EnumerableSet.AddressSet storage) {
        return LibMembers.accessData().members;
    }
}
