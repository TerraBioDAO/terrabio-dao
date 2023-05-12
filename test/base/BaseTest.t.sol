// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { UtilsTest } from "./UtilsTest.t.sol";

import { ADMIN_ROLE, MEMBER_ROLE } from "src/dao_access/Roles.sol";

import { TerrabioDao } from "src/TerrabioDao.sol";
import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";
import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { DiamondLoupe } from "src/diamond_retrocompability/DiamondLoupe.sol";
import { Governance } from "src/governance/Governance.sol";
import { Pausable } from "src/pausable/Pausable.sol";
import { SelectorPause } from "src/pausable/SelectorPause.sol";

contract BaseTest is UtilsTest {
    // address of main contract
    address internal DAO;

    // modules/features
    address internal ACCESS;
    address internal ROUTER;
    address internal DIAMOND;
    address internal PAUSABLE;
    address internal SELECTOR_PAUSE;
    address internal GOV;

    modifier daoDeployed() {
        if (DAO == address(0)) revert("DeployDAO first");
        _;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                          DEPLOY & BOOTSTRAP
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _deployFullDAO(
        address[] memory members
    )
        internal
        returns (FallbackRouter router, DaoAccess access, DiamondLoupe diamond, Governance gov)
    {
        (router, access) = _deployDAO();
        diamond = _bootstrapDiamondLoupe();
        _bootstrapPausable();
        gov = _bootstrapGovernance(members);
    }

    function _deployDAO() internal returns (FallbackRouter router, DaoAccess access) {
        vm.startPrank(OWNER);
        router = new FallbackRouter();
        ROUTER = address(router);

        access = new DaoAccess(OWNER);
        ACCESS = address(access);

        TerrabioDao dao = new TerrabioDao(ACCESS, ROUTER);
        DAO = address(dao);

        // post deployment config --- daoAccess
        bytes4[] memory access_selectors = new bytes4[](6);
        access_selectors[0] = DaoAccess.hasRole.selector;
        access_selectors[1] = DaoAccess.grantRole.selector;
        access_selectors[2] = DaoAccess.revokeRole.selector;
        access_selectors[3] = DaoAccess.renounceRole.selector;
        access_selectors[4] = DaoAccess.getRoleAdmin.selector;
        access_selectors[5] = DaoAccess.setAdminRole.selector;

        address[] memory access_impl = new address[](6);
        access_impl[0] = ACCESS;
        access_impl[1] = ACCESS;
        access_impl[2] = ACCESS;
        access_impl[3] = ACCESS;
        access_impl[4] = ACCESS;
        access_impl[5] = ACCESS;

        FallbackRouter(DAO).batchUpdateFunction(access_selectors, access_impl);

        // DAO is set as ADMIN => to use vm.prank(DAO);
        DaoAccess(DAO).grantRole(ADMIN_ROLE, DAO);

        vm.stopPrank();

        vm.label(OWNER, "OWNER");
        vm.label(DAO, "DAO_MAIN");
        vm.label(ACCESS, "ACCESS");
        vm.label(ROUTER, "ROUTER");
    }

    function _bootstrapDiamondLoupe() internal daoDeployed returns (DiamondLoupe diamond) {
        diamond = new DiamondLoupe();
        DIAMOND = address(diamond);

        // register functions
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

        vm.label(DIAMOND, "DIAMOND");
    }

    function _bootstrapGovernance(
        address[] memory members
    ) internal daoDeployed returns (Governance gov) {
        gov = new Governance();
        GOV = address(gov);

        // register functions
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

        // add members
        if (members.length == 0) revert("Empty member list to bootstrap DAO");

        for (uint256 i; i < members.length; i++) {
            DaoAccess(DAO).grantRole(MEMBER_ROLE, members[i]);
        }

        // finish config
        Governance(DAO).bootstrap();
        DaoAccess(DAO).renounceRole(ADMIN_ROLE, OWNER);
        vm.stopPrank();

        vm.label(GOV, "GOV");
    }

    function _bootstrapPausable()
        internal
        returns (Pausable pausable, SelectorPause selectorPause)
    {
        pausable = new Pausable();
        PAUSABLE = address(pausable);

        // register functions
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Pausable.unpause.selector;
        selectors[1] = Pausable.pause.selector;
        selectors[2] = Pausable.paused.selector;

        address[] memory impl = new address[](3);
        impl[0] = PAUSABLE;
        impl[1] = PAUSABLE;
        impl[2] = PAUSABLE;

        vm.startPrank(OWNER);
        FallbackRouter(DAO).batchUpdateFunction(selectors, impl);

        selectorPause = new SelectorPause();
        SELECTOR_PAUSE = address(selectorPause);

        selectors = new bytes4[](4);
        selectors[0] = SelectorPause.pauseModule.selector;
        selectors[1] = SelectorPause.unpauseModule.selector;
        selectors[2] = SelectorPause.batchPauseSelectors.selector;
        selectors[3] = SelectorPause.batchUnpauseSelectors.selector;

        impl = new address[](4);
        impl[0] = SELECTOR_PAUSE;
        impl[1] = SELECTOR_PAUSE;
        impl[2] = SELECTOR_PAUSE;
        impl[3] = SELECTOR_PAUSE;

        FallbackRouter(DAO).batchUpdateFunction(selectors, impl);

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              MANAGE MEMBERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _setAsMember(address account) internal {
        vm.prank(DAO);
        DaoAccess(DAO).grantRole(MEMBER_ROLE, account);
    }

    function _setAsMember(address[] memory accounts) internal {
        vm.startPrank(DAO);
        for (uint256 i; i < accounts.length; i++) {
            DaoAccess(DAO).grantRole(MEMBER_ROLE, accounts[i]);
        }
        vm.stopPrank();
    }

    function _addFunction(bytes4 selector, address impl) internal daoDeployed {
        vm.prank(DAO);
        FallbackRouter(DAO).updateFunction(selector, impl);
    }
}
