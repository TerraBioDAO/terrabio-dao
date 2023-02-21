// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {ContractRegistry} from "src/ContractRegistry.sol";

contract deploy is Script {
    address internal DEPLOYER;

    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_GOERLI");
        DEPLOYER = vm.addr(pk);

        console.log(DEPLOYER);
        console.log(DEPLOYER.balance);

        vm.startBroadcast(pk);

        ContractRegistry c_registry = new ContractRegistry(DEPLOYER);

        c_registry.whitelistAddr(address(502));

        vm.stopBroadcast();
    }
}
