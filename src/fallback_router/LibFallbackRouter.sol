// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

library LibFallbackRouter {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct Data {
        mapping(bytes4 => address) impls;
        mapping(bytes4 => address[]) history;
        EnumerableSet.Bytes32Set selectors;
    }

    /// @dev Emitted when adding, replacing or removing functions selector
    event FunctionUpdated(
        bytes4 indexed selector,
        address indexed oldImpl,
        address indexed newImpl
    );

    /// @dev Error for inexistant selector
    error NotImplemented(bytes4 selector);

    /// @dev Storage slot for Data struct
    bytes32 internal constant STORAGE_SLOT =
        keccak256("terrabiodao.contracts.storage.FallbackRouter.v1");

    /// @return data Data struct at `STORAGE_SLOT`
    function accessData() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}
