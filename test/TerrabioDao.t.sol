// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {TerrabioDao} from "src/TerrabioDao.sol";
import {FallbackRouter} from "src/fallback_router/FallbackRouter.sol";

contract TerrabioDao_test is Test {
    address internal DAO;
    FallbackRouter internal router;
    address internal ROUTER;

    address internal constant OWNER = address(501);

    function setUp() public {
        vm.startPrank(OWNER);
        router = new FallbackRouter();
        ROUTER = address(router);

        TerrabioDao dao = new TerrabioDao(ROUTER);
        DAO = address(dao);

        vm.stopPrank();
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
}
