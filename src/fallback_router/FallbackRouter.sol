// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { ListLengthMismatch } from "src/common/Errors.sol";
import { Implementation } from "src/common/Implementation.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";
import { RoleControl } from "src/dao_access/RoleControl.sol";
import { LibFallbackRouter } from "./LibFallbackRouter.sol";

/**
 * @title Implementation for routing calls made on the main contract.
 * @dev All write functions are restricted to the ADMIN_ROLE for securities reasons.
 * NOTE selectors collisions are not considered in the smart contract, users should be aware
 * before updating a function.
 */
contract FallbackRouter is Implementation, RoleControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @dev permissionless function as delegatecall from the
     * DAO is not authorized (only in constructor)
     */
    function bootstrap() external {
        LibFallbackRouter.Data storage data = _data();

        _updateFunction(this.batchUpdateFunction.selector, IMPL_ADDR, data);
        _updateFunction(this.updateFunction.selector, IMPL_ADDR, data);
        _updateFunction(this.rollback.selector, IMPL_ADDR, data);
        _updateFunction(this.getFunctionImpl.selector, IMPL_ADDR, data);
        _updateFunction(this.getFunctionHistory.selector, IMPL_ADDR, data);
        _updateFunction(this.getSelectorList.selector, IMPL_ADDR, data);

        _updateFunction(bytes4(0), IMPL_ADDR, data);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * Retrieve implementation contract address for a selector OR revert with error
     * @param selectors array of selectors to update
     * @return impl implementation contract address
     */
    function getImpl(bytes4 selector) external onlyRole(ADMIN_ROLE) returns (address impl) {
        LibFallbackRouter.Data storage data = _data();
        address impl = data.impls[selector];
        //if (impl == address(1)) revert ModulePaused(selector);
        if (impl == address(0)) revert LibFallbackRouter.NotImplemented(selector);

        return impl;
    }

    /**
     * @notice Batch functions update
     * @param selectors array of selectors to update
     * @param impls array of addresses corresponding to the `selectors` array
     */
    function batchUpdateFunction(
        bytes4[] memory selectors,
        address[] memory impls
    ) public onlyRole(ADMIN_ROLE) {
        LibFallbackRouter.Data storage data = _data();
        if (selectors.length != impls.length) revert ListLengthMismatch();

        for (uint256 i; i < selectors.length; ) {
            _updateFunction(selectors[i], impls[i], data);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Update a function
     * @param selector the selector to update
     * @param impl implementation address
     */
    function updateFunction(bytes4 selector, address impl) external onlyRole(ADMIN_ROLE) {
        _updateFunction(selector, impl, _data());
    }

    /**
     * @notice Update a function to its previous implementation
     * @dev can only rollback to the previous implementation, it cannot
     * go further in the history.
     *
     * @param selector function's selector to rollback
     */
    function rollback(bytes4 selector) external onlyRole(ADMIN_ROLE) {
        LibFallbackRouter.Data storage data = _data();
        address currentImpl = data.impls[selector];
        address rollbackedImpl = data.history[selector][data.history[selector].length - 1];

        data.impls[selector] = rollbackedImpl;

        emit LibFallbackRouter.FunctionUpdated(selector, currentImpl, rollbackedImpl);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                  GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @return address implementing the function's `selector`
    function getFunctionImpl(bytes4 selector) external view returns (address) {
        return _data().impls[selector];
    }

    /// @return array of implementation address for the `selector`
    function getFunctionHistory(bytes4 selector) external view returns (address[] memory) {
        return _data().history[selector];
    }

    /// @return list of selector callable in the DAO system
    function getSelectorList() external view returns (bytes4[] memory) {
        bytes32[] memory rawSelectors = _data().selectors.values();
        bytes4[] memory selectors = new bytes4[](rawSelectors.length);
        for (uint256 i; i < rawSelectors.length; ) {
            selectors[i] = bytes4(rawSelectors[i]);
            unchecked {
                ++i;
            }
        }

        return selectors;
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

        // update the selector list
        impl == address(0) ? data.selectors.remove(selector) : data.selectors.add(selector);

        emit LibFallbackRouter.FunctionUpdated(selector, oldImpl, impl);
    }

    function _data() internal pure returns (LibFallbackRouter.Data storage) {
        return LibFallbackRouter.accessData();
    }
}
