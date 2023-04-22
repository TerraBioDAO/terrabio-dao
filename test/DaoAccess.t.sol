// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ADMIN_ROLE, MEMBER_ROLE} from "src/dao_access/Roles.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";
import {RoleGated} from "test/mocks/RoleGated.sol";

contract DaoAccess_test is Test {
    DaoAccess internal access;
    address internal ACCESS;

    RoleGated internal roleGated;
    address internal ROLE_GATED;

    address internal constant OWNER = address(501);
    address internal constant USER = address(1);
    address internal constant VISITOR = address(2);
    address internal constant VISITOR2 = address(3);

    bytes32 internal constant ROLE_3 = bytes32(uint256(2 ** 3));
    bytes32 internal constant ROLE_4 = bytes32(uint256(2 ** 4));
    bytes32 internal constant ROLE_5 = bytes32(uint256(2 ** 5));
    bytes32 internal constant ROLE_6 = bytes32(uint256(2 ** 6));

    function setUp() public {
        access = new DaoAccess(OWNER);
        ACCESS = address(access);
        vm.prank(OWNER);
        access.bootstrap();

        roleGated = new RoleGated();
        ROLE_GATED = address(roleGated);

        vm.label(OWNER, "OWNER");
        vm.label(USER, "USER");
        vm.label(VISITOR, "VISITOR");
        vm.label(VISITOR2, "VISITOR2");
    }

    function test_constructor_bootstrap(address addr) public {
        vm.assume(addr != OWNER);
        assertTrue(access.hasRole(ADMIN_ROLE, OWNER));
        assertFalse(access.hasRole(ADMIN_ROLE, addr));
    }

    function test_grantRole_GrantRole(address addr) public {
        vm.prank(OWNER);
        access.grantRole(ROLE_3, addr);

        assertTrue(access.hasRole(ROLE_3, addr));
    }

    function test_grantRole_CannotGrantRole() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "NotRoleOperator(bytes32,bytes32)",
                ROLE_3,
                ADMIN_ROLE
            )
        );
        access.grantRole(ROLE_3, USER);
    }

    function test_grantRole_GrantSeveralRolesAtOnce() public {
        vm.prank(OWNER);
        access.grantRole(ROLE_3 | ROLE_4 | ROLE_5, USER);

        assertTrue(access.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_4 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_3 | ROLE_4, USER));
        assertTrue(access.hasRole(ROLE_3 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_4, USER));
        assertTrue(access.hasRole(ROLE_3, USER));
    }

    function test_grantRole_GrantSeveralRoles() public {
        vm.startPrank(OWNER);
        access.grantRole(ROLE_5, USER);
        access.grantRole(ROLE_4, USER);
        access.grantRole(ROLE_3, USER);

        assertTrue(access.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_4 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_3 | ROLE_4, USER));
        assertTrue(access.hasRole(ROLE_3 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_4, USER));
        assertTrue(access.hasRole(ROLE_3, USER));
    }

    function test_grantRole_OperatorGrantRole() public {
        // ROLE_3 can grant ROLE_4
        vm.startPrank(OWNER);
        access.setAdminRole(ROLE_4, ROLE_3);
        access.grantRole(ROLE_3, USER);
        vm.stopPrank();

        assertEq(access.getRoleAdmin(ROLE_4), ROLE_3);
        assertTrue(access.hasRole(ROLE_3, USER));

        vm.prank(USER);
        access.grantRole(ROLE_4, VISITOR);
        assertTrue(access.hasRole(ROLE_4, VISITOR));
    }

    function test_revokeRole_RevokeRole() public {
        test_grantRole_GrantRole(USER); // reuse test
        vm.prank(OWNER);
        access.revokeRole(ROLE_3, USER);
        assertFalse(access.hasRole(ROLE_3, USER));
    }

    function test_revokeRole_CannotRevokeRole() public {
        test_grantRole_GrantRole(USER);
        vm.expectRevert(
            abi.encodeWithSignature(
                "NotRoleOperator(bytes32,bytes32)",
                ROLE_3,
                ADMIN_ROLE
            )
        );
        access.revokeRole(ROLE_3, USER);
    }

    function test_revokeRole_RevokeSeveralRoleAtOnce() public {
        test_grantRole_GrantSeveralRolesAtOnce();
        vm.prank(OWNER);
        access.revokeRole(ROLE_3 | ROLE_4 | ROLE_5, USER);

        assertFalse(access.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_4 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_3 | ROLE_4, USER));
        assertFalse(access.hasRole(ROLE_3 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_4, USER));
        assertFalse(access.hasRole(ROLE_3, USER));
    }

    function test_revokeRole_RevokeOneRoleAmongSeveral() public {
        test_grantRole_GrantSeveralRolesAtOnce();
        vm.prank(OWNER);
        access.revokeRole(ROLE_5, USER);

        assertFalse(access.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_4 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_3 | ROLE_4, USER));
        assertFalse(access.hasRole(ROLE_3 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_4, USER));
        assertTrue(access.hasRole(ROLE_3, USER));
    }

    function test_revokeRole_RevokeTwoRoleAmongSeveral() public {
        test_grantRole_GrantSeveralRolesAtOnce();
        vm.prank(OWNER);
        access.revokeRole(ROLE_3 | ROLE_4, USER);

        assertFalse(access.hasRole(ROLE_3 | ROLE_4 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_4 | ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_3 | ROLE_4, USER));
        assertFalse(access.hasRole(ROLE_3 | ROLE_5, USER));
        assertTrue(access.hasRole(ROLE_5, USER));
        assertFalse(access.hasRole(ROLE_4, USER));
        assertFalse(access.hasRole(ROLE_3, USER));
    }

    function test_revokeRole_OperatorCanRevoke() public {
        test_grantRole_OperatorGrantRole();
        vm.prank(USER);
        access.revokeRole(ROLE_4, VISITOR);
        assertFalse(access.hasRole(ROLE_4, VISITOR));
    }

    function test_renounceRole_RoleOwnerCanRenounceRole() public {
        test_grantRole_GrantRole(USER);
        vm.prank(USER);
        access.renounceRole(ROLE_3, USER);
        assertFalse(access.hasRole(ROLE_3, USER));
    }

    function test_renounceRole_OnlyOwnerCanRenounceRole() public {
        test_grantRole_GrantRole(USER);
        vm.prank(VISITOR);
        vm.expectRevert(abi.encodeWithSignature("NotSelfRenouncement()"));
        access.renounceRole(ROLE_3, USER);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("NotSelfRenouncement()"));
        access.renounceRole(ROLE_3, USER);
    }

    function test_setAdminRole_AssignOperatorRole() public {
        vm.prank(OWNER);
        access.setAdminRole(ROLE_3, ROLE_4);

        assertEq(access.getRoleAdmin(ROLE_3), ROLE_4);
    }

    function test_setAdminRole_NewOperatorOverridePrevious() public {
        test_setAdminRole_AssignOperatorRole();
        vm.prank(OWNER);
        access.setAdminRole(ROLE_3, ROLE_5);

        assertEq(access.getRoleAdmin(ROLE_3), ROLE_5);
    }

    function test_setAdminRole_OnlyAdminCanAssignOperator() public {
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSignature(
                "MissingRole(address,bytes32)",
                USER,
                ADMIN_ROLE
            )
        );
        access.setAdminRole(ROLE_3, ROLE_5);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                    ROLE CONTROL MODIFIER TESTS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function test_onlyRole_OnlyAllowedRoleAccess() public {
        test_grantRole_GrantRole(USER);
        assertTrue(access.hasRole(ADMIN_ROLE, OWNER));
        workaround_UseAccessStorageForRoleGated();

        vm.prank(USER);
        assertTrue(roleGated.gate(ROLE_3));

        vm.prank(OWNER);
        assertTrue(roleGated.adminGate());
    }

    function test_onlyRole_OnlyAllowedRolesAccess() public {
        test_grantRole_GrantRole(USER);
        vm.prank(OWNER);
        access.grantRole(ROLE_5, VISITOR);
        vm.prank(OWNER);
        access.grantRole(ROLE_5 | ROLE_3, VISITOR2);
        workaround_UseAccessStorageForRoleGated();

        vm.prank(USER);
        assertTrue(roleGated.gate(ROLE_3));
        // assertTrue(roleGated.gate(ROLE_3 | ROLE_5)); not work

        vm.prank(VISITOR);
        assertTrue(roleGated.gate(ROLE_5));
        // assertTrue(roleGated.gate(ROLE_3 | ROLE_5)); not work

        // work only when both role has been granted
        vm.prank(VISITOR2);
        assertTrue(roleGated.gate(ROLE_5 | ROLE_3));
    }

    function test_onlyRole_BlockUnauthorizedMembers() public {
        test_grantRole_GrantRole(USER);
        workaround_UseAccessStorageForRoleGated();

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSignature(
                "MissingRole(address,bytes32)",
                USER,
                ROLE_4
            )
        );
        roleGated.gate(ROLE_4);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                WORKAROUNDS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function workaround_UseAccessStorageForRoleGated() internal {
        vm.etch(ACCESS, ROLE_GATED.code);
        roleGated = RoleGated(ACCESS);
    }
}
