// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {ContractRegistry} from "src/ContractRegistry.sol";

contract ContractRegistry_test is Test {
    // states
    address internal constant OWNER = address(501);
    ContractRegistry internal c_registry;

    function setUp() public {
        // run at `forge test`
        c_registry = new ContractRegistry(OWNER);
    }

    function test_contructor_Ownership() public {
        assertEq(c_registry.owner(), OWNER, "owner set");
    }

    function test_whitelistAddr_AddAddr() public {
        address CONTRACT_ADDR = address(1);
        vm.prank(OWNER);
        c_registry.whitelistAddr(CONTRACT_ADDR);

        assertTrue(c_registry.isWhitelisted(CONTRACT_ADDR));
    }

    function test_whitelistAddr_FuzzAddAddr(address addr) public {
        vm.assume(addr != address(0));
        vm.prank(OWNER);
        c_registry.whitelistAddr(addr);

        assertTrue(c_registry.isWhitelisted(addr));
    }

    function test_whitelistAddr_CannotAddAddr() public {
        address CONTRACT_ADDR = address(1);
        vm.expectRevert("Ownable: caller is not the owner");
        c_registry.whitelistAddr(CONTRACT_ADDR);
    }

    event Whitelisted(address indexed addr, address setter);

    function test_whitelistAddr_Emit() public {
        address CONTRACT_ADDR = address(1);
        vm.expectEmit(true, false, false, true, address(c_registry));
        emit Whitelisted(CONTRACT_ADDR, OWNER);
        vm.prank(OWNER);
        c_registry.whitelistAddr(CONTRACT_ADDR);
    }

    function test_whitelistAddr_EmitWithLogs() public {
        address CONTRACT_ADDR = address(1);
        vm.recordLogs(); // start record
        vm.prank(OWNER);
        c_registry.whitelistAddr(CONTRACT_ADDR);
        VmSafe.Log[] memory logs = vm.getRecordedLogs(); // stop record
        assertEq(logs.length, 1); // only Whitelisted emmited

        // topics = ["event name", indexed1, indexed2, indexed3]
        assertEq(logs[0].topics.length, 2);
        assertEq(
            logs[0].topics[0],
            keccak256(abi.encodePacked("Whitelisted(address,address)"))
            // can be found with `forge inspect <contract> events`
        );
        assertEq(logs[0].topics[1], bytes32(abi.encode(CONTRACT_ADDR)));

        // data = abi.encode(non indexed args)
        assertEq(abi.decode(logs[0].data, (address)), OWNER);
    }

    function test_contructor_ForkOwnership() public {
        vm.createSelectFork("goerli", 8486194);

        emit log_named_uint("chain ID:", block.chainid);
        emit log_named_uint("chain ID:", block.number);
    }
}
