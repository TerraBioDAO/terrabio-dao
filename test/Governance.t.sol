// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { BaseTest } from "test/base/BaseTest.t.sol";

import { Governance } from "src/governance/Governance.sol";
import { Callable } from "./mocks/Callable.sol";

contract Governance_test is BaseTest {
    Callable internal callable;
    address internal CALLABLE;

    Governance internal gov_impl;
    Governance internal dao;

    function setUp() public {
        _newUsersSet(0, 4);
        _deployDAO();
        gov_impl = _bootstrapGovernance(USERS);
        dao = Governance(DAO);

        callable = new Callable();
        CALLABLE = address(callable);

        _addFunction(Callable.pingMe.selector, CALLABLE);
        callable = Callable(DAO);
    }

    function test_setup() public {
        bytes[] memory calls = new bytes[](0);
        vm.prank(USERS[0]);
        dao.propose(1000, 2 days, 0, 10000, calls);
    }

    function test_propose_StartAProposal() public returns (uint256 proposalId) {
        assertEq(uint8(dao.getProposalStatus(420)), 0); // unknown

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encode(CALLABLE, abi.encodeWithSignature("pingMe(uint256)", 42));
        // abi.encodePacked(
        //     abi.encodePacked(CALLABLE),
        //     abi.encodeWithSignature("pingMe(uint256)", 42)
        // );

        vm.prank(USERS[0]);
        proposalId = dao.propose(12_000, 2 days, 5 days, 10000, calls);

        // check info
        assertTrue(dao.getProposal(proposalId).active);
        assertEq(dao.getProposal(proposalId).startAt, 12_000);
        assertEq(dao.getProposal(proposalId).endAt, 12_000 + 2 days);
        assertEq(dao.getProposal(proposalId).gracePeriod, 5 days);
        assertEq(dao.getProposal(proposalId).threshold, 10000);
        assertEq(dao.getProposal(proposalId).proposer, USERS[0]);
        assertEq(dao.getProposal(proposalId).calls[0], calls[0]);

        assertEq(uint8(dao.getProposalStatus(proposalId)), 1); // pending

        vm.warp(13_000);

        assertEq(uint8(dao.getProposalStatus(proposalId)), 2); // ongoing

        vm.warp(block.timestamp + 2 days);

        assertEq(uint8(dao.getProposalStatus(proposalId)), 3); //voted

        vm.warp(block.timestamp + 5 days);

        assertEq(uint8(dao.getProposalStatus(proposalId)), 4); //ready
        vm.warp(0);
    }

    function test_propose_AllMemberVoteYes() public returns (uint256 proposalId) {
        proposalId = test_propose_StartAProposal();
        vm.warp(13_000);
        vm.prank(OWNER);
        dao.vote(proposalId, 1);
        vm.prank(USERS[0]);
        dao.vote(proposalId, 1);
        vm.prank(USERS[1]);
        dao.vote(proposalId, 1);
        vm.prank(USERS[2]);
        dao.vote(proposalId, 1);

        assertEq(uint8(dao.getProposalStatus(proposalId)), 2);

        vm.prank(USERS[3]);
        dao.vote(proposalId, 1);

        assertEq(uint8(dao.getProposalStatus(proposalId)), 4);
    }

    function test_execute_FulfillProposal() public {
        uint256 proposalId = test_propose_AllMemberVoteYes();

        // prank any
        dao.execute(proposalId);
        assertEq(uint8(dao.getProposalStatus(proposalId)), 6);
    }
}

import { FacetTest } from "test/base/FacetTest.sol";

contract Governance_security_test is FacetTest {
    function setUp() public {
        facetName = "Governance";
        functionExceptionIdentifiers.push("fe0d94c1"); // execute
        functionExceptionIdentifiers.push("b384abef"); // vote
        functionExceptionIdentifiers.push("678abbf7"); // propose

        _newUsersSet(0, 4);
        _deployFullDAO(USERS);

        // After Dao deployment
        IMPL = GOV;
    }
}
