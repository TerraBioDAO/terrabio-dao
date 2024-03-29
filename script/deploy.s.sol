// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import { MEMBER_ROLE, ADMIN_ROLE } from "src/dao_access/Roles.sol";

import { TerrabioDao } from "src/TerrabioDao.sol";
import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";
import { Governance } from "src/governance/Governance.sol";

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
        bytes4[] memory selectors = new bytes4[](13);
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
        selectors[12] = Governance.getAllProposals.selector;

        address[] memory impls = new address[](13);
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
        impls[12] = address(gov);

        FallbackRouter(DAO).batchUpdateFunction(selectors, impls);

        // init Governance storage and remove "bootstrap()"
        Governance(DAO).bootstrap();
        FallbackRouter(DAO).updateFunction(Governance.bootstrap.selector, address(0));

        // init roles in the DAO
        // anvil(0) = OWNER | DEPLOYER
        DaoAccess(DAO).grantRole(
            MEMBER_ROLE,
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8 // anvil(1)
        );
        // DaoAccess(DAO).grantRole(
        //     MEMBER_ROLE,
        //     0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC // anvil(2)
        // );
        // DaoAccess(DAO).grantRole(
        //     MEMBER_ROLE,
        //     0x90F79bf6EB2c4f870365E785982E1f101E93b906 // anvil(3)
        // );

        // Assing DAO as ADMIN
        DaoAccess(DAO).grantRole(ADMIN_ROLE, DAO);

        // DEPLOYER renounce his ADMIN_ROLE
        DaoAccess(DAO).renounceRole(ADMIN_ROLE, DEPLOYER);

        // create proposal
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encode(
            DAO,
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                MEMBER_ROLE,
                0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC // anvil(3)
            )
        );

        Governance(DAO).propose(0, 2 days, 0 days, 8000, calls);
        Governance(DAO).propose(0, 2 days, 0 days, 8000, new bytes[](0));

        // vote
        Governance(DAO).vote(1, 1);

        vm.stopBroadcast();
    }
}
