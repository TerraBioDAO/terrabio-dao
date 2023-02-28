// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/utils/DynamicalMemoryArray.sol";

contract DynamicalMemoryArray_test is Test {
    using DynamicalMemoryArray for uint256;

    function test_create_AppendToFreeMemory() public {
        uint256 key = DynamicalMemoryArray.create(5); // 0x80
        key.push(5); // 0xa0
        key.push(5); // 0xc0
        key.push(5); // 0xe0
        key.push(5); // 0x100
        // 0x120

        // NOT POSSIBLE IN FORGE => MEMORY IS MANIPULATED

        emit log_uint(workaround_readMemory(0x40));

        workaround_appendToMemory(999);

        assertEq(key.at(0), 5);
        assertEq(key.at(1), 5);
        assertEq(key.at(2), 5);
        assertEq(key.at(3), 5);
        assertEq(key.at(4), 0);
        emit log_uint(workaround_readMemory(288));

        assertEq(workaround_readMemory(0x140), 999);

        key.push(6);
        key.push(6);
        key.push(6);
        key.push(6);

        assertEq(workaround_readMemory(0x140), 6);
    }

    function workaround_appendToMemory(uint256 value) internal {
        uint256 current_ptr;
        assembly {
            current_ptr := mload(0x40)
        }
        workaround_storeInMemoryAt(current_ptr, value);
    }

    function workaround_storeInMemoryAt(uint256 mem_slot, uint256 value)
        internal
    {
        assembly {
            mstore(mem_slot, value)
        }
    }

    function workaround_readMemory(uint256 mem_slot)
        internal
        view
        returns (uint256 ret)
    {
        assembly {
            ret := mload(mem_slot)
        }
    }
}
