// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { BaseTest } from "test/base/BaseTest.t.sol";

import { ListLengthMismatch, NotImplementedError } from "src/common/Errors.sol";
import { ADMIN_ROLE, MEMBER_ROLE } from "src/dao_access/Roles.sol";

import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";
import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { DiamondLoupe } from "src/diamond_retrocompability/DiamondLoupe.sol";
import { Governance } from "src/governance/Governance.sol";
import { Pausable } from "src/pausable/Pausable.sol";
import { SelectorPause } from "src/pausable/SelectorPause.sol";

contract TerrabioDao_test is BaseTest {
    // features
    DaoAccess internal access;
    FallbackRouter internal router;
    DiamondLoupe internal diamond;
    Pausable internal pausable;
    Governance internal gov;

    function setUp() public {
        _newUsersSet(0, 4);
        (router, access, diamond, gov) = _deployFullDAO(USERS);
        router = FallbackRouter(DAO);
        access = DaoAccess(DAO);
        diamond = DiamondLoupe(DAO);
        gov = Governance(DAO);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                             CONSTRUCTOR
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function test_constructor_BootstrapRouter() public {
        assertEq(router.getFunctionImpl(FallbackRouter.batchUpdateFunction.selector), ROUTER);
        assertEq(router.getFunctionImpl(FallbackRouter.updateFunction.selector), ROUTER);
        assertEq(router.getFunctionImpl(FallbackRouter.rollback.selector), ROUTER);
        assertEq(router.getFunctionImpl(FallbackRouter.getFunctionImpl.selector), ROUTER);
        assertEq(router.getFunctionImpl(FallbackRouter.getFunctionHistory.selector), ROUTER);
        assertEq(router.getFunctionImpl(FallbackRouter.getSelectorList.selector), ROUTER);
    }

    function test_constructor_BootstrapAccess() public {
        bytes4 selector = 0xbad00000;
        address impl = address(0xbad00000);

        // start from new deployment
        _deployDAO();
        router = FallbackRouter(DAO);

        // only OWNER could call `updateFunction`
        vm.prank(OWNER);
        router.updateFunction(selector, impl);

        // check if no revert
        assertEq(router.getFunctionImpl(selector), impl);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                             POST DEPLOYMENT CONFIG
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function test_postDeployment_DaoAccessConfigured() public {
        assertEq(router.getFunctionImpl(DaoAccess.hasRole.selector), ACCESS);
        assertEq(router.getFunctionImpl(DaoAccess.grantRole.selector), ACCESS);
        assertEq(router.getFunctionImpl(DaoAccess.revokeRole.selector), ACCESS);
        assertEq(router.getFunctionImpl(DaoAccess.renounceRole.selector), ACCESS);
        assertEq(router.getFunctionImpl(DaoAccess.getRoleAdmin.selector), ACCESS);
    }

    function test_postDeployment_Pausable() public {
        assertEq(router.getFunctionImpl(Pausable.paused.selector), PAUSABLE);
        assertEq(router.getFunctionImpl(Pausable.pause.selector), PAUSABLE);
        assertEq(router.getFunctionImpl(Pausable.unpause.selector), PAUSABLE);

        assertFalse(Pausable(DAO).paused());

        assertEq(router.getFunctionImpl(SelectorPause.pauseModule.selector), SELECTOR_PAUSE);
        assertEq(router.getFunctionImpl(SelectorPause.unpauseModule.selector), SELECTOR_PAUSE);
        assertEq(
            router.getFunctionImpl(SelectorPause.batchPauseSelectors.selector),
            SELECTOR_PAUSE
        );
        assertEq(
            router.getFunctionImpl(SelectorPause.batchUnpauseSelectors.selector),
            SELECTOR_PAUSE
        );
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                           GOVERNANCE
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function test_governance_DaoManagerRouterWithGovernance() public {
        // try by adding random function
        bytes4 selector1 = 0xbad00001;
        address impl1 = address(0xbad00001);
        bytes4 selector2 = 0xbad00002;
        address impl2 = address(0xbad00002);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encode(
            DAO,
            abi.encodeWithSignature("updateFunction(bytes4,address)", selector1, impl1)
        );
        calls[1] = abi.encode(
            DAO,
            abi.encodeWithSignature("updateFunction(bytes4,address)", selector2, impl2)
        );

        vm.prank(USERS[3]);
        uint256 proposalId = Governance(DAO).propose(100, 2 days, 0, 10000, calls);

        vm.warp(200);

        vm.prank(OWNER);
        gov.vote(proposalId, 1);
        vm.prank(USERS[0]);
        gov.vote(proposalId, 1);
        vm.prank(USERS[1]);
        gov.vote(proposalId, 1);
        vm.prank(USERS[2]);
        gov.vote(proposalId, 1);
        vm.prank(USERS[3]);
        gov.vote(proposalId, 1);

        gov.execute(proposalId);

        assertEq(router.getFunctionImpl(selector1), impl1);
        assertEq(router.getFunctionImpl(selector2), impl2);

        assertEq(router.getSelectorList().length, 32);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                        ADD DIAMOND RETROCOMPABILITY
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function test_diamond_AddRetrocompability() public {
        bytes4[] memory selectors = new bytes4[](4);
        address[] memory impl = new address[](4);
        selectors[0] = DiamondLoupe.facets.selector;
        selectors[1] = DiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupe.facetAddresses.selector;
        selectors[3] = DiamondLoupe.facetAddress.selector;
        impl[0] = DIAMOND;
        impl[1] = DIAMOND;
        impl[2] = DIAMOND;
        impl[3] = DIAMOND;

        vm.prank(DAO);
        router.batchUpdateFunction(selectors, impl);

        DiamondLoupe.Facet[] memory facets = diamond.facets();

        assertEq(facets.length, 6);
    }
}
