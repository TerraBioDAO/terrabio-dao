// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { Test, Vm } from "forge-std/Test.sol";
import { BaseTest } from "test/base/BaseTest.t.sol";

import { SelectorPause } from "src/pausable/SelectorPause.sol";
import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";
import { DiamondLoupe } from "src/diamond_retrocompability/DiamondLoupe.sol";
import { Governance } from "src/governance/Governance.sol";
import { Pausable } from "src/pausable/Pausable.sol";

import { LibDaoAccess } from "src/dao_access/LibDaoAccess.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";

contract SelectorPause_test is Test {
    SelectorPause internal selectorPause;

    address internal DEPLOYER;
    address internal OWNER;

    constructor() {
        DEPLOYER = address(0x1);
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

        // Move DaoAccess storage to SelectorPause
        vm.etch(address(access), address(new SelectorPause()).code);
        selectorPause = SelectorPause(address(access));
        assertEq(vm.load(address(selectorPause), reads[0]), roles);
    }

    function testSetup() public {
        assertFalse(false);
    }
}

contract SelectorPause_global_test is BaseTest {
    function setUp() public {
        _newUsersSet(0, 4);
        _deployFullDAO(USERS);
    }

    function testSetup() public {
        vm.startPrank(AN_USER);
        assertFalse(Pausable(DAO).paused());
        assertFalse(DaoAccess(DAO).hasRole(ADMIN_ROLE, OWNER));
        assertTrue(DaoAccess(DAO).hasRole(ADMIN_ROLE, DAO));
        vm.stopPrank();

        /*vm.prank(AN_USER);
        vm.expectRevert(
            abi.encodeWithSelector(LibDaoAccess.MissingRole.selector, AN_USER, ADMIN_ROLE)
        );
        Pausable(DAO).pause();*/
    }

    function test_batchPauseUnpauseSelectors() public {
        address impl = DiamondLoupe(DAO).facetAddress(Pausable.paused.selector);
        assertEq(impl, PAUSABLE);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Pausable.paused.selector;
        vm.prank(DAO);
        SelectorPause(DAO).batchPauseSelectors(selectors);

        vm.prank(AN_USER);
        impl = DiamondLoupe(DAO).facetAddress(Pausable.paused.selector);
        assertEq(impl, SELECTOR_PAUSE);

        vm.prank(DAO);
        SelectorPause(DAO).batchUnpauseSelectors(selectors);

        vm.prank(AN_USER);
        impl = DiamondLoupe(DAO).facetAddress(Pausable.paused.selector);
        assertEq(impl, PAUSABLE);
    }

    function test_pauseUnpauseModule() public {
        //bytes4[] memory selectors = DiamondLoupe(DAO).facetFunctionSelectors(PAUSABLE);
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Pausable.paused.selector;
        selectors[1] = Pausable.pause.selector;
        selectors[2] = Pausable.unpause.selector;

        address impl;

        for (uint i; i < selectors.length; i++) {
            vm.prank(AN_USER);
            impl = DiamondLoupe(DAO).facetAddress(selectors[i]);
            assertEq(impl, PAUSABLE);
        }

        vm.prank(DAO);
        SelectorPause(DAO).pauseModule(PAUSABLE);

        for (uint i; i < selectors.length; i++) {
            vm.prank(AN_USER);
            impl = DiamondLoupe(DAO).facetAddress(selectors[i]);
            assertEq(impl, SELECTOR_PAUSE);
        }

        vm.prank(DAO);
        SelectorPause(DAO).unpauseModule(PAUSABLE);

        for (uint i; i < selectors.length; i++) {
            vm.prank(AN_USER);
            impl = DiamondLoupe(DAO).facetAddress(selectors[i]);
            assertEq(impl, PAUSABLE);
        }
    }

    function test_fallback() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Pausable.paused.selector;
        vm.prank(DAO);
        SelectorPause(DAO).batchPauseSelectors(selectors);

        vm.prank(DAO);
        vm.expectRevert(abi.encodeWithSelector(SelectorPause.SelectorIsPaused.selector));
        Pausable(DAO).paused();
    }
}

import { FacetTest } from "test/base/FacetTest.sol";

contract SelectorPause_security_test is FacetTest {
    function setUp() public {
        facetName = "SelectorPause";
        // functionExceptionIdentifiers.push("execute");

        _newUsersSet(0, 4);
        _deployFullDAO(USERS);

        // After Dao deployment
        IMPL = SELECTOR_PAUSE;
    }
}
