// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ADMIN_ROLE, MEMBER_ROLE} from "src/dao_access/Roles.sol";
import {LibGovernance} from "src/governance/LibGovernance.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";
import {Governance} from "src/governance/Governance.sol";
import {Callable} from "./mocks/Callable.sol";

contract Governance_test is Test {
    Callable internal callable;
    address internal CALLABLE;

    Governance internal gov;
    address internal GOV;

    address internal constant OWNER = address(501);
    // address internal constant USER1 = address(1);
    address internal constant USER2 = address(2);
    address internal constant USER3 = address(3);
    address internal constant USER4 = address(4);
    address internal constant USER5 = address(5);

    function setUp() public {
        callable = new Callable();
        CALLABLE = address(callable);

        // role setup
        DaoAccess access = new DaoAccess(OWNER);
        vm.startPrank(OWNER);
        access.hasRole(ADMIN_ROLE, OWNER);
        access.bootstrap();
        access.grantRole(ADMIN_ROLE, address(access));
        // access.grantRole(USER1, MEMBER_ROLE);
        access.grantRole(MEMBER_ROLE, USER2);
        access.grantRole(MEMBER_ROLE, USER3);
        access.grantRole(MEMBER_ROLE, USER4);
        access.grantRole(MEMBER_ROLE, USER5);
        access.renounceRole(ADMIN_ROLE, OWNER);
        vm.stopPrank();

        // move access & members storage to Governance
        vm.etch(address(access), address(new Governance()).code);
        gov = Governance(address(access));
        GOV = address(gov);

        // bootstrap
        vm.prank(GOV);
        gov.bootstrap();
    }

    function test_setup() public {
        bytes[] memory calls = new bytes[](0);
        vm.prank(USER3);
        gov.propose(1000, 2 days, 0, 10000, calls);
    }

    function test_propose_StartAProposal() public returns (uint256 proposalId) {
        assertEq(uint8(gov.getProposalStatus(420)), 0); // unknown

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encode(
            CALLABLE,
            abi.encodeWithSignature("pingMe(uint256)", 42)
        );
        // abi.encodePacked(
        //     abi.encodePacked(CALLABLE),
        //     abi.encodeWithSignature("pingMe(uint256)", 42)
        // );

        vm.prank(USER4);
        proposalId = gov.propose(12_000, 2 days, 5 days, 10000, calls);

        // check info
        assertTrue(gov.getProposal(proposalId).active);
        assertEq(gov.getProposal(proposalId).startAt, 12_000);
        assertEq(gov.getProposal(proposalId).endAt, 12_000 + 2 days);
        assertEq(gov.getProposal(proposalId).gracePeriod, 5 days);
        assertEq(gov.getProposal(proposalId).threshold, 10000);
        assertEq(gov.getProposal(proposalId).proposer, USER4);
        assertEq(gov.getProposal(proposalId).calls[0], calls[0]);

        assertEq(uint8(gov.getProposalStatus(proposalId)), 1); // pending

        vm.warp(13_000);

        assertEq(uint8(gov.getProposalStatus(proposalId)), 2); // ongoing

        vm.warp(block.timestamp + 2 days);

        assertEq(uint8(gov.getProposalStatus(proposalId)), 3); //voted

        vm.warp(block.timestamp + 5 days);

        assertEq(uint8(gov.getProposalStatus(proposalId)), 4); //ready
        vm.warp(0);
    }

    function test_propose_AllMemberVoteYes()
        public
        returns (uint256 proposalId)
    {
        proposalId = test_propose_StartAProposal();
        vm.warp(13_000);
        vm.prank(OWNER);
        gov.vote(proposalId, 1);
        vm.prank(USER2);
        gov.vote(proposalId, 1);
        vm.prank(USER3);
        gov.vote(proposalId, 1);
        vm.prank(USER4);
        gov.vote(proposalId, 1);

        assertEq(uint8(gov.getProposalStatus(proposalId)), 2);

        vm.prank(USER5);
        gov.vote(proposalId, 1);

        assertEq(uint8(gov.getProposalStatus(proposalId)), 4);
    }

    function test_execute_FulfillProposal() public {
        uint256 proposalId = test_propose_AllMemberVoteYes();

        // prank any
        gov.execute(proposalId);
    }
}
