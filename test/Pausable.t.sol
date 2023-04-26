// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Test, Vm } from "forge-std/Test.sol";

import { Pausable } from "src/pausable/Pausable.sol";
import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { LibDaoAccess } from "src/dao_access/LibDaoAccess.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";

contract Pausable_test is Test {
    Pausable internal pausable;

    address internal DEPLOYER;
    address internal OWNER;
    address internal AN_USER;

    constructor() {
        DEPLOYER = address(0x1);
        AN_USER = address(0x2);
        OWNER = DEPLOYER;
    }

    function setUp() public {
        // Create storage for DaoAccess
        vm.startPrank(DEPLOYER);
        DaoAccess access = new DaoAccess(DEPLOYER);
        access.bootstrap();
        vm.stopPrank();

        vm.record();
        assert(access.hasRole(ADMIN_ROLE, OWNER));
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(access));
        assertEq(reads.length, 1);
        assertEq(writes.length, 0);
        bytes32 roles = vm.load(address(access), reads[0]);

        // Move DaoAccess storage to Pausable
        vm.etch(address(access), address(new Pausable()).code);
        pausable = Pausable(address(access));
        assertEq(vm.load(address(pausable), reads[0]), roles);
    }

    function testSetup() public {
        assertFalse(pausable.paused());
    }

    function testPause() public {
        // test caller has Admin role requirement
        vm.prank(AN_USER);
        vm.expectRevert(
            abi.encodeWithSignature("MissingRole(address,bytes32)", AN_USER, ADMIN_ROLE)
        );
        pausable.pause();

        Vm.Log[] memory logs;
        vm.recordLogs();

        vm.prank(OWNER);
        pausable.pause();
        assertTrue(pausable.paused());

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics.length, 2); // hash + 1 indexed var
        assertEq(logs[0].topics[0], keccak256("Paused(address)"));
        assertEq(abi.decode(abi.encode(logs[0].topics[1]), (address)), OWNER);

        // test whenNotPaused requirement
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("AlreadyPaused()"));
        pausable.pause();
    }

    function testUnpause() public {
        vm.prank(OWNER);
        pausable.pause();

        // test caller has Admin role requirement
        vm.prank(AN_USER);
        vm.expectRevert(
            abi.encodeWithSignature("MissingRole(address,bytes32)", AN_USER, ADMIN_ROLE)
        );
        pausable.unpause();

        Vm.Log[] memory logs;
        vm.recordLogs();

        vm.prank(OWNER);
        pausable.unpause();
        assertFalse(pausable.paused());

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].topics.length, 2); // hash + 1 indexed var
        assertEq(logs[0].topics[0], keccak256("Unpaused(address)"));
        assertEq(abi.decode(abi.encode(logs[0].topics[1]), (address)), OWNER);

        // test whenPaused requirement
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("NotPaused()"));
        pausable.unpause();
    }
}
