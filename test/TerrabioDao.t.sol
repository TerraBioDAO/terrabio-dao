// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ListLengthMismatch, NotImplementedError} from "src/common/Errors.sol";

import {ADMIN_ROLE, MEMBER_ROLE} from "src/dao_access/Roles.sol";

import {LibDaoAccess} from "src/dao_access/LibDaoAccess.sol";
import {LibFallbackRouter} from "src/fallback_router/LibFallbackRouter.sol";

import {TerrabioDao} from "src/TerrabioDao.sol";

import {FallbackRouter} from "src/fallback_router/FallbackRouter.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";
import {DiamondLoupe, IDiamondLoupe} from "src/diamond_retrocompability/DiamondLoupe.sol";
import {Governance} from "src/governance/Governance.sol";

contract TerrabioDao_test is Test {
    // main contract address
    address internal DAO;

    // features
    DaoAccess internal access;
    address internal ACCESS;
    FallbackRouter internal router;
    address internal ROUTER;
    DiamondLoupe internal diamond;
    address internal DIAMOND;
    Governance internal gov;
    address internal GOV;

    // roles
    address internal constant OWNER = address(501);

    function setUp() public {
        vm.startPrank(OWNER);
        router = new FallbackRouter();
        ROUTER = address(router);

        access = new DaoAccess(OWNER);
        ACCESS = address(access);

        diamond = new DiamondLoupe();
        DIAMOND = address(diamond);

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
        vm.label(DIAMOND, "DIAMOND");
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

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                           GOVERNANCE
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function test_governance_DaoManagerRouterWithGovernance() public {
        address USER1 = address(1);
        address USER2 = address(2);
        address USER3 = address(3);
        address USER4 = address(4);

        // deploy
        gov = new Governance();
        GOV = address(gov);

        // config router
        bytes4[] memory gov_selectors = new bytes4[](7);
        gov_selectors[0] = Governance.bootstrap.selector;
        gov_selectors[1] = Governance.vote.selector;
        gov_selectors[2] = Governance.propose.selector;
        gov_selectors[3] = Governance.execute.selector;
        gov_selectors[4] = Governance.cancelProposal.selector;
        gov_selectors[5] = Governance.getProposalStatus.selector;
        gov_selectors[6] = Governance.getProposal.selector;

        address[] memory gov_impl = new address[](7);
        gov_impl[0] = GOV;
        gov_impl[1] = GOV;
        gov_impl[2] = GOV;
        gov_impl[3] = GOV;
        gov_impl[4] = GOV;
        gov_impl[5] = GOV;
        gov_impl[6] = GOV;

        vm.startPrank(OWNER);
        FallbackRouter(DAO).batchUpdateFunction(gov_selectors, gov_impl);

        DaoAccess(DAO).grantRole(MEMBER_ROLE, USER1);
        DaoAccess(DAO).grantRole(MEMBER_ROLE, USER2);
        DaoAccess(DAO).grantRole(MEMBER_ROLE, USER3);
        DaoAccess(DAO).grantRole(MEMBER_ROLE, USER4);
        DaoAccess(DAO).grantRole(ADMIN_ROLE, DAO);
        Governance(DAO).bootstrap();
        DaoAccess(DAO).renounceRole(ADMIN_ROLE, OWNER);
        vm.stopPrank();

        // try by adding random function
        bytes4 selector1 = 0xbad00001;
        address impl1 = address(0xbad00001);
        bytes4 selector2 = 0xbad00002;
        address impl2 = address(0xbad00002);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encode(
            DAO,
            abi.encodeWithSignature(
                "updateFunction(bytes4,address)",
                selector1,
                impl1
            )
        );
        calls[1] = abi.encode(
            DAO,
            abi.encodeWithSignature(
                "updateFunction(bytes4,address)",
                selector2,
                impl2
            )
        );

        vm.prank(USER3);
        uint256 proposalId = Governance(DAO).propose(
            100,
            2 days,
            0,
            10000,
            calls
        );

        vm.warp(200);

        vm.prank(OWNER);
        Governance(DAO).vote(proposalId, 1);
        vm.prank(USER1);
        Governance(DAO).vote(proposalId, 1);
        vm.prank(USER2);
        Governance(DAO).vote(proposalId, 1);
        vm.prank(USER3);
        Governance(DAO).vote(proposalId, 1);
        vm.prank(USER4);
        Governance(DAO).vote(proposalId, 1);

        Governance(DAO).execute(proposalId);

        assertEq(FallbackRouter(DAO).getFunctionImpl(selector1), impl1);
        assertEq(FallbackRouter(DAO).getFunctionImpl(selector2), impl2);

        assertEq(FallbackRouter(DAO).getSelectorList().length, 20);
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

        vm.prank(OWNER);
        FallbackRouter(DAO).batchUpdateFunction(selectors, impl);

        DiamondLoupe.Facet[] memory facets = DiamondLoupe(DAO).facets();

        assertEq(facets.length, 3);
    }
}
