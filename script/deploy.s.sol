// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {TerrabioDao} from "src/TerrabioDao.sol";
import {DaoAccess} from "src/dao_access/DaoAccess.sol";
import {FallbackRouter} from "src/fallback_router/FallbackRouter.sol";

contract deploy is Script {
    address internal DEPLOYER;

    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_ANVIL");
        DEPLOYER = vm.addr(pk);

        console.log(DEPLOYER);
        console.log(DEPLOYER.balance);

        vm.startBroadcast(pk);

        FallbackRouter router = new FallbackRouter();
        DaoAccess access = new DaoAccess(DEPLOYER);

        TerrabioDao dao = new TerrabioDao(address(access), address(router));

        // post deployment config
        // add DaoAccess methods
        bytes4[] memory access_selectors = new bytes4[](5);
        access_selectors[0] = DaoAccess.hasRole.selector;
        access_selectors[1] = DaoAccess.grantRole.selector;
        access_selectors[2] = DaoAccess.revokeRole.selector;
        access_selectors[3] = DaoAccess.renounceRole.selector;
        access_selectors[4] = DaoAccess.getRoleAdmin.selector;

        address[] memory access_impl = new address[](5);
        access_impl[0] = address(access);
        access_impl[1] = address(access);
        access_impl[2] = address(access);
        access_impl[3] = address(access);
        access_impl[4] = address(access);

        FallbackRouter(address(dao)).batchUpdateFunction(
            access_selectors,
            access_impl
        );

        vm.stopBroadcast();
    }
}
