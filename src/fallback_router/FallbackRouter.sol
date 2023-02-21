// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {ListLengthMismatch} from "src/common/Errors.sol";
import {Implementation} from "src/common/Implementation.sol";
import {LibFallbackRouter} from "./LibFallbackRouter.sol";

contract FallbackRouter is Implementation {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function bootstrap() external {
        LibFallbackRouter.Data storage data = _data();

        _updateFunction(this.batchUpdateFunction.selector, IMPL_ADDR, data);
        _updateFunction(this.updateFunction.selector, IMPL_ADDR, data);
        _updateFunction(this.rollback.selector, IMPL_ADDR, data);
        _updateFunction(this.getFunctionImpl.selector, IMPL_ADDR, data);
        _updateFunction(this.getFunctionHistory.selector, IMPL_ADDR, data);
        _updateFunction(this.getSelectorList.selector, IMPL_ADDR, data);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    function batchUpdateFunction(
        bytes4[] memory selectors,
        address[] memory impls
    ) public {
        LibFallbackRouter.Data storage data = _data();
        if (selectors.length != impls.length) revert ListLengthMismatch();

        for (uint256 i; i < selectors.length; ) {
            _updateFunction(selectors[i], impls[i], data);
            unchecked {
                ++i;
            }
        }
    }

    function updateFunction(bytes4 selector, address impl) external {
        _updateFunction(selector, impl, _data());
    }

    function rollback(bytes4 selector) external {
        LibFallbackRouter.Data storage data = _data();
        address currentImpl = data.impls[selector];
        address rollbackedImpl = data.history[selector][
            data.history[selector].length - 1
        ];

        data.impls[selector] = rollbackedImpl;

        emit LibFallbackRouter.FunctionUpdated(
            selector,
            currentImpl,
            rollbackedImpl
        );
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                  GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function getFunctionImpl(bytes4 selector) external view returns (address) {
        return _data().impls[selector];
    }

    function getFunctionHistory(bytes4 selector)
        external
        view
        returns (address[] memory)
    {
        return _data().history[selector];
    }

    function getSelectorList()
        external
        view
        returns (bytes4[] memory selectors)
    {
        bytes32[] memory rawSelectors = _data().selectors.values();
        for (uint256 i; i < rawSelectors.length; ) {
            selectors[i] = bytes4(rawSelectors[i]);
            unchecked {
                ++i;
            }
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _updateFunction(
        bytes4 selector,
        address impl,
        LibFallbackRouter.Data storage data
    ) internal {
        address oldImpl = data.impls[selector];

        if (oldImpl != address(0)) data.history[selector].push(oldImpl);
        data.impls[selector] = impl;
        impl == address(0)
            ? data.selectors.remove(selector)
            : data.selectors.add(selector);

        emit LibFallbackRouter.FunctionUpdated(selector, oldImpl, impl);
    }

    function _data() internal pure returns (LibFallbackRouter.Data storage) {
        return LibFallbackRouter.accessData();
    }
}
