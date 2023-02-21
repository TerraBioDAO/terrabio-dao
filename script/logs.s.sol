// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

contract logs is Script {
    function run() public {
        console.log("ChainID", block.chainid);

        // call blockchain
    }
}
