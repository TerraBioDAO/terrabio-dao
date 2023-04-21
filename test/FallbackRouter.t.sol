// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ADMIN_ROLE} from "src/dao_access/Roles.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";
import {FallbackRouter} from "src/fallback_router/FallbackRouter.sol";

contract FallbackRouter_test is Test {
    FallbackRouter internal router;
    address internal ROUTER;

    address internal constant OWNER = address(501);
    address internal constant USER = address(1);

    function setUp() public {
        // write OWNER's admin role in Router storage
        DaoAccess access = new DaoAccess(OWNER);
        vm.prank(OWNER);
        access.bootstrap();

        // deploy a fallback router
        FallbackRouter r = new FallbackRouter();

        // assign router code to access
        vm.etch(address(access), address(r).code);
        router = FallbackRouter(address(access));
        ROUTER = address(router);
    }

    function test_updateFunction_UpdateAFunction() public {
        bytes4 selector = 0xbad00000;
        address impl = address(0xbad00000);
        vm.prank(OWNER);
        router.updateFunction(selector, impl);

        assertEq(router.getFunctionImpl(selector), impl);
    }

    function test_updateFunction_OnlyOwnerCanUpdate() public {
        bytes4 selector = 0xbad00000;
        address impl = address(0xbad00000);

        vm.prank(USER);

        vm.expectRevert(
            abi.encodeWithSignature(
                "MissingRole(address,bytes32)",
                USER,
                ADMIN_ROLE
            )
        );
        router.updateFunction(selector, impl);
    }

    function test_getSelectorList_ReturnListOfSelectors() public {
        router.getSelectorList();
    }
}
