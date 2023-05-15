// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { BaseTest } from "test/base/BaseTest.t.sol";
import { ADMIN_ROLE, MEMBER_ROLE } from "src/dao_access/Roles.sol";

import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";

contract FallbackRouter_test is BaseTest {
    FallbackRouter internal router_impl;
    FallbackRouter internal dao;

    function setUp() public {
        _newUsersSet(0, 5);
        (router_impl, ) = _deployDAO();
        dao = FallbackRouter(DAO);
    }

    function test_updateFunction_UpdateAFunction() public {
        bytes4 selector = 0xbad00000;
        address impl = address(0xbad00000);
        vm.prank(OWNER);
        dao.updateFunction(selector, impl);

        assertEq(dao.getFunctionImpl(selector), impl);
    }

    function test_updateFunction_OnlyOwnerCanUpdate() public {
        bytes4 selector = 0xbad00000;
        address impl = address(0xbad00000);

        vm.prank(USERS[0]);

        vm.expectRevert(
            abi.encodeWithSignature("MissingRole(address,bytes32)", USERS[0], ADMIN_ROLE)
        );
        dao.updateFunction(selector, impl);
    }

    function test_getSelectorList_ReturnListOfSelectors() public {
        dao.getSelectorList();
    }
}

import { FacetTest } from "test/base/FacetTest.sol";

contract FallbackRouter_security_test is FacetTest {
    function setUp() public {
        facetName = "FallbackRouter";
        // functionExceptionSelectors.push("execute");

        _newUsersSet(0, 4);
        _deployFullDAO(USERS);

        // After Dao deployment
        IMPL = ROUTER;
    }
}
