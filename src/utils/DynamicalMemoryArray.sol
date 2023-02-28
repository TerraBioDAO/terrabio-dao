// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library DynamicalMemoryArray {
    function create(uint256 max_size) internal pure returns (uint256 mem_ptr) {
        uint256 new_ptr;
        uint256[] memory memoryArray = new uint256[](0);

        assembly {
            mem_ptr := sub(mload(0x40), 0x20)
            new_ptr := add(mem_ptr, mul(max_size, 32))
            mstore(0x40, add(mem_ptr, mul(max_size, 32)))
        }

        require(new_ptr <= 0xFFFF, "DMA: too far in memory");
    }

    function createAt(uint256 mem_ptr) internal pure {
        require(mem_ptr <= 0xFFFF, "DMA: too far in memory");

        // save current free memory pointer
        uint256 current_ptr;
        assembly {
            current_ptr := mload(0x40)
            mstore(0x40, mem_ptr)
        }

        // store empty array in `mem_ptr`
        uint256[] memory memoryArray = new uint256[](0);

        // resume to free memory pointer
        assembly {
            mstore(0x40, current_ptr)
        }
    }

    function push(uint256 mem_ptr, uint256 value) internal pure {
        assembly {
            let size := add(mload(mem_ptr), 1)
            mstore(mem_ptr, size)
            mstore(add(mem_ptr, mul(size, 32)), value)
        }
    }

    function pop(uint256 mem_ptr) internal pure {
        assembly {
            let size := mload(mem_ptr)
            mstore(add(mem_ptr, mul(size, 32)), 0)
            mstore(mem_ptr, sub(size, 1))
        }
    }

    function toArray(uint256 mem_ptr) internal pure returns (uint256[] memory) {
        uint256 size;
        uint256 current_ptr;

        assembly {
            size := mload(mem_ptr)
            current_ptr := mload(0x40)
            mstore(0x40, mem_ptr)
        }

        uint256[] memory createdArray = new uint256[](0);

        assembly {
            mstore(mem_ptr, size)
            mstore(0x40, current_ptr)
        }

        return createdArray;
    }

    function length(uint256 mem_ptr) internal pure returns (uint256 size) {
        assembly {
            size := mload(mem_ptr)
        }
    }

    function at(uint256 mem_ptr, uint256 index)
        internal
        pure
        returns (uint256 ret)
    {
        assembly {
            ret := mload(add(mem_ptr, mul(32, add(index, 1))))
        }
    }
}
