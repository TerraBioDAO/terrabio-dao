// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { BaseTest } from "test/base/BaseTest.t.sol";

import { ADMIN_ROLE, MEMBER_ROLE } from "src/dao_access/Roles.sol";

import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { RoleGated } from "test/mocks/RoleGated.sol";

contract DaoAccess_test is BaseTest {
    DaoAccess internal access_impl;
    DaoAccess internal dao;

    RoleGated internal roleGated;
    address internal ROLE_GATED;

    bytes32 internal constant ROLE_3 = bytes32(uint256(2 ** 3));
    bytes32 internal constant ROLE_4 = bytes32(uint256(2 ** 4));
    bytes32 internal constant ROLE_5 = bytes32(uint256(2 ** 5));
    bytes32 internal constant ROLE_6 = bytes32(uint256(2 ** 6));

    function setUp() public {
        _newUsersSet(0, 5);
        (, access_impl) = _deployDAO();
        dao = DaoAccess(DAO);

        roleGated = new RoleGated();
        ROLE_GATED = address(roleGated);

        // set a mock role gated on the DAO
        _addFunction(RoleGated.gate.selector, ROLE_GATED);
        _addFunction(RoleGated.adminGate.selector, ROLE_GATED);
        roleGated = RoleGated(DAO);
    }

    function test_constructor_bootstrap(address addr) public {
        vm.assume(addr != OWNER && addr != DAO);
        assertTrue(dao.hasRole(ADMIN_ROLE, OWNER));
        assertTrue(dao.hasRole(ADMIN_ROLE, DAO));
        assertFalse(dao.hasRole(ADMIN_ROLE, addr));
    }

    function test_grantRole_GrantRole(address addr) public {
        vm.prank(OWNER);
        dao.grantRole(ROLE_3, addr);

        assertTrue(dao.hasRole(ROLE_3, addr));
    }

    function test_grantRole_CannotGrantRole() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotRoleOperator(bytes32,bytes32)", ROLE_3, ADMIN_ROLE)
        );
        dao.grantRole(ROLE_3, USERS[0]);
    }

    function test_grantRole_GrantSeveralRolesAtOnce() public {
        vm.prank(OWNER);
        dao.grantRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]);

        assertTrue(dao.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_4 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3 | ROLE_4, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_4, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_grantRole_GrantSeveralRoles() public {
        vm.startPrank(OWNER);
        dao.grantRole(ROLE_5, USERS[0]);
        dao.grantRole(ROLE_4, USERS[0]);
        dao.grantRole(ROLE_3, USERS[0]);

        assertTrue(dao.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_4 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3 | ROLE_4, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_4, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_grantRole_OperatorGrantRole() public {
        // ROLE_3 can grant ROLE_4
        vm.startPrank(OWNER);
        dao.setAdminRole(ROLE_4, ROLE_3);
        dao.grantRole(ROLE_3, USERS[0]);
        vm.stopPrank();

        assertEq(dao.getRoleAdmin(ROLE_4), ROLE_3);
        assertTrue(dao.hasRole(ROLE_3, USERS[0]));

        vm.prank(USERS[0]);
        dao.grantRole(ROLE_4, USERS[1]);
        assertTrue(dao.hasRole(ROLE_4, USERS[1]));
    }

    function test_revokeRole_RevokeRole() public {
        test_grantRole_GrantRole(USERS[0]); // reuse test
        vm.prank(OWNER);
        dao.revokeRole(ROLE_3, USERS[0]);
        assertFalse(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_revokeRole_CannotRevokeRole() public {
        test_grantRole_GrantRole(USERS[0]);
        vm.expectRevert(
            abi.encodeWithSignature("NotRoleOperator(bytes32,bytes32)", ROLE_3, ADMIN_ROLE)
        );
        dao.revokeRole(ROLE_3, USERS[0]);
    }

    function test_revokeRole_RevokeSeveralRoleAtOnce() public {
        test_grantRole_GrantSeveralRolesAtOnce();
        vm.prank(OWNER);
        dao.revokeRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]);

        assertFalse(dao.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_4 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3 | ROLE_4, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_4, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_revokeRole_RevokeOneRoleAmongSeveral() public {
        test_grantRole_GrantSeveralRolesAtOnce();
        vm.prank(OWNER);
        dao.revokeRole(ROLE_5, USERS[0]);

        assertFalse(dao.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_4 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3 | ROLE_4, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_4, USERS[0]));
        assertTrue(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_revokeRole_RevokeTwoRoleAmongSeveral() public {
        test_grantRole_GrantSeveralRolesAtOnce();
        vm.prank(OWNER);
        dao.revokeRole(ROLE_3 | ROLE_4, USERS[0]);

        assertFalse(dao.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_4 | ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3 | ROLE_4, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3 | ROLE_5, USERS[0]));
        assertTrue(dao.hasRole(ROLE_5, USERS[0]));
        assertFalse(dao.hasRole(ROLE_4, USERS[0]));
        assertFalse(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_revokeRole_OperatorCanRevoke() public {
        test_grantRole_OperatorGrantRole();
        vm.prank(USERS[0]);
        dao.revokeRole(ROLE_4, USERS[1]);
        assertFalse(dao.hasRole(ROLE_4, USERS[1]));
    }

    function test_renounceRole_RoleOwnerCanRenounceRole() public {
        test_grantRole_GrantRole(USERS[0]);
        vm.prank(USERS[0]);
        dao.renounceRole(ROLE_3, USERS[0]);
        assertFalse(dao.hasRole(ROLE_3, USERS[0]));
    }

    function test_renounceRole_OnlyOwnerCanRenounceRole() public {
        test_grantRole_GrantRole(USERS[0]);
        vm.prank(USERS[1]);
        vm.expectRevert(abi.encodeWithSignature("NotSelfRenouncement()"));
        dao.renounceRole(ROLE_3, USERS[0]);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("NotSelfRenouncement()"));
        dao.renounceRole(ROLE_3, USERS[0]);
    }

    function test_setAdminRole_AssignOperatorRole() public {
        vm.prank(OWNER);
        dao.setAdminRole(ROLE_3, ROLE_4);

        assertEq(dao.getRoleAdmin(ROLE_3), ROLE_4);
    }

    function test_setAdminRole_NewOperatorOverridePrevious() public {
        test_setAdminRole_AssignOperatorRole();
        vm.prank(OWNER);
        dao.setAdminRole(ROLE_3, ROLE_5);

        assertEq(dao.getRoleAdmin(ROLE_3), ROLE_5);
    }

    function test_setAdminRole_OnlyAdminCanAssignOperator() public {
        vm.prank(USERS[0]);
        vm.expectRevert(
            abi.encodeWithSignature("MissingRole(address,bytes32)", USERS[0], ADMIN_ROLE)
        );
        dao.setAdminRole(ROLE_3, ROLE_5);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                    ROLE CONTROL MODIFIER TESTS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function test_onlyRole_OnlyAllowedRoleAccess() public {
        test_grantRole_GrantRole(USERS[0]);
        assertTrue(dao.hasRole(ADMIN_ROLE, OWNER));

        vm.prank(USERS[0]);
        assertTrue(roleGated.gate(ROLE_3));

        vm.prank(OWNER);
        assertTrue(roleGated.adminGate());
    }

    function test_onlyRole_OnlyAllowedRolesAccess() public {
        test_grantRole_GrantRole(USERS[0]);
        vm.prank(OWNER);
        dao.grantRole(ROLE_5, USERS[1]);
        vm.prank(OWNER);
        dao.grantRole(ROLE_5 | ROLE_3, USERS[2]);

        vm.prank(USERS[0]);
        assertTrue(roleGated.gate(ROLE_3));
        // assertTrue(roleGated.gate(ROLE_3 | ROLE_5)); not work

        vm.prank(USERS[1]);
        assertTrue(roleGated.gate(ROLE_5));
        // assertTrue(roleGated.gate(ROLE_3 | ROLE_5)); not work

        // work only when both role has been granted
        vm.prank(USERS[2]);
        assertTrue(roleGated.gate(ROLE_5 | ROLE_3));
    }

    function test_onlyRole_BlockUnauthorizedMembers() public {
        test_grantRole_GrantRole(USERS[0]);

        vm.prank(USERS[0]);
        vm.expectRevert(abi.encodeWithSignature("MissingRole(address,bytes32)", USERS[0], ROLE_4));
        roleGated.gate(ROLE_4);
    }
}

import { FacetTest } from "test/base/FacetTest.sol";

contract DaoAccess_security_test is FacetTest {
    function setUp() public {
        facetName = "DaoAccess";
        // functionExceptionSelectors.push("execute");

        _newUsersSet(0, 4);
        _deployFullDAO(USERS);

        // After Dao deployment
        IMPL = ACCESS;
    }
}
