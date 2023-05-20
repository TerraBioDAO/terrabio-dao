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

contract DiamondLoupe_test is BaseTest {
    function setUp() public {
        _newUsersSet(0, 4);
        _deployFullDAO(USERS);
    }

    function test_facetFunctionSelectors() public {
        vm.prank(AN_USER);
        bytes4[] memory FacetSelectors = DiamondLoupe(DAO).facetFunctionSelectors(PAUSABLE);
        assertEq(FacetSelectors.length, 3);
    }
}

import { FacetTest } from "test/base/FacetTest.sol";

contract DiamondLoupe_security_test is FacetTest {
    function setUp() public {
        facetName = "DiamondLoupe";
        // functionExceptionIdentifiers.push("execute");

        _newUsersSet(0, 4);
        _deployFullDAO(USERS);

        // After Dao deployment
        IMPL = DIAMOND;
    }
}
