// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ADMIN_ROLE, MEMBER_ROLE} from "src/dao_access/Roles.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";

contract DaoAccess_test is Test {
    DaoAccess internal access;
    address internal ACCESS;

    address internal constant OWNER = address(501);
    address internal constant USER = address(1);
    address internal constant VISITOR = address(2);

    bytes32 internal constant ROLE_3 = bytes32(uint256(2 ** 3));
    bytes32 internal constant ROLE_4 = bytes32(uint256(2 ** 4));
    bytes32 internal constant ROLE_5 = bytes32(uint256(2 ** 5));
    bytes32 internal constant ROLE_6 = bytes32(uint256(2 ** 6));

    function setUp() public {
        access = new DaoAccess(OWNER);
        ACCESS = address(access);
        vm.prank(OWNER);
        access.bootstrap();
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

    function test_grantRole_GrantSeveralRoles() public {
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
}
