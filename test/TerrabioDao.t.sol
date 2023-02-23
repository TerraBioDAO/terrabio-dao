// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ListLengthMismatch, NotImplementedError} from "src/common/Errors.sol";

import {ADMIN_ROLE} from "src/dao_access/Roles.sol";

import {LibDaoAccess} from "src/dao_access/LibDaoAccess.sol";
import {LibFallbackRouter} from "src/fallback_router/LibFallbackRouter.sol";

import {TerrabioDao} from "src/TerrabioDao.sol";
import {FallbackRouter} from "src/fallback_router/FallbackRouter.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";

contract TerrabioDao_test is Test {
    // main contract address
    address internal DAO;

    // features
    DaoAccess internal access;
    address internal ACCESS;
    FallbackRouter internal router;
    address internal ROUTER;

    // roles
    address internal constant OWNER = address(501);

    function setUp() public {
        vm.startPrank(OWNER);
        router = new FallbackRouter();
        ROUTER = address(router);

        access = new DaoAccess(OWNER);
        ACCESS = address(access);

        TerrabioDao dao = new TerrabioDao(ACCESS, ROUTER);
        DAO = address(dao);

        // post deployment config
        // add DaoAccess methods
        bytes4[] memory access_selectors = new bytes4[](5);
        access_selectors[0] = DaoAccess.hasRole.selector;
        access_selectors[1] = DaoAccess.grantRole.selector;
        access_selectors[2] = DaoAccess.revokeRole.selector;
        access_selectors[3] = DaoAccess.renounceRole.selector;
        access_selectors[4] = DaoAccess.getRoleAdmin.selector;

        address[] memory access_impl = new address[](5);
        access_impl[0] = ACCESS;
        access_impl[1] = ACCESS;
        access_impl[2] = ACCESS;
        access_impl[3] = ACCESS;
        access_impl[4] = ACCESS;

        FallbackRouter(DAO).batchUpdateFunction(access_selectors, access_impl);

        vm.stopPrank();

        vm.label(OWNER, "OWNER");
        vm.label(DAO, "DAO");
        vm.label(ACCESS, "ACCESS");
        vm.label(ROUTER, "ROUTER");
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                             CONSTRUCTOR
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function test_constructor_BootstrapRouter() public {
        FallbackRouter dao = FallbackRouter(DAO);
        assertEq(
            dao.getFunctionImpl(FallbackRouter.batchUpdateFunction.selector),
            ROUTER
        );
        assertEq(
            dao.getFunctionImpl(FallbackRouter.updateFunction.selector),
            ROUTER
        );
        assertEq(dao.getFunctionImpl(FallbackRouter.rollback.selector), ROUTER);
        assertEq(
            dao.getFunctionImpl(FallbackRouter.getFunctionImpl.selector),
            ROUTER
        );
        assertEq(
            dao.getFunctionImpl(FallbackRouter.getFunctionHistory.selector),
            ROUTER
        );
        assertEq(
            dao.getFunctionImpl(FallbackRouter.getSelectorList.selector),
            ROUTER
        );
    }

    function test_constructor_BootstrapAccess() public {
        bytes4 selector = 0xbad00000;
        address impl = address(0xbad00000);

        // only OWNER could call `updateFunction`
        vm.prank(OWNER);
        router = FallbackRouter(DAO);
        router.updateFunction(selector, impl);

        // check if no revert
        assertEq(router.getFunctionImpl(selector), impl);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                             POST DEPLOYMENT CONFIG
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function test_postDeployment_DaoAccessConfigured() public {
        router = FallbackRouter(DAO);
        assertEq(router.getFunctionImpl(DaoAccess.hasRole.selector), ACCESS);
        assertEq(router.getFunctionImpl(DaoAccess.grantRole.selector), ACCESS);
        assertEq(router.getFunctionImpl(DaoAccess.revokeRole.selector), ACCESS);
        assertEq(
            router.getFunctionImpl(DaoAccess.renounceRole.selector),
            ACCESS
        );
        assertEq(
            router.getFunctionImpl(DaoAccess.getRoleAdmin.selector),
            ACCESS
        );
    }
}
