// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {TerrabioDao} from "src/TerrabioDao.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";
import {FallbackRouter} from "src/fallback_router/FallbackRouter.sol";
import {Governance} from "src/governance/Governance.sol";

contract deploy is Script {
    address internal DEPLOYER;
    address internal DAO;

    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_ANVIL");
        DEPLOYER = vm.addr(pk);

        console.log(DEPLOYER);
        console.log(DEPLOYER.balance);

        vm.startBroadcast(pk);

        // deploy implementations
        FallbackRouter router = new FallbackRouter();
        DaoAccess access = new DaoAccess(DEPLOYER);
        Governance gov = new Governance();

        // deploy main contract
        TerrabioDao dao = new TerrabioDao(address(access), address(router));
        DAO = address(dao);

        // Add new functions (DaoAccess + Governance)
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = DaoAccess.hasRole.selector;
        selectors[1] = DaoAccess.grantRole.selector;
        selectors[2] = DaoAccess.revokeRole.selector;
        selectors[3] = DaoAccess.renounceRole.selector;
        selectors[4] = DaoAccess.getRoleAdmin.selector;
        // ---
        selectors[5] = Governance.bootstrap.selector;
        selectors[6] = Governance.vote.selector;
        selectors[7] = Governance.propose.selector;
        selectors[8] = Governance.execute.selector;
        selectors[9] = Governance.cancelProposal.selector;
        selectors[10] = Governance.getProposalStatus.selector;
        selectors[11] = Governance.getProposal.selector;

        address[] memory impls = new address[](12);
        impls[0] = address(access);
        impls[1] = address(access);
        impls[2] = address(access);
        impls[3] = address(access);
        impls[4] = address(access);
        // ---
        impls[5] = address(gov);
        impls[6] = address(gov);
        impls[7] = address(gov);
        impls[8] = address(gov);
        impls[9] = address(gov);
        impls[10] = address(gov);
        impls[11] = address(gov);

        FallbackRouter(DAO).batchUpdateFunction(selectors, impls);

        // init Governance storage and remove "bootstrap()"
        Governance(DAO).bootstrap();
        FallbackRouter(DAO).updateFunction(
            Governance.bootstrap.selector,
            address(0)
        );

        vm.stopBroadcast();
    }
}
