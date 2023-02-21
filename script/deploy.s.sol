// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

contract deploy is Script {
    address internal DEPLOYER;

    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_GOERLI");
        DEPLOYER = vm.addr(pk);

        console.log(DEPLOYER);
        console.log(DEPLOYER.balance);

        vm.startBroadcast(pk);

        vm.stopBroadcast();
    }
}
