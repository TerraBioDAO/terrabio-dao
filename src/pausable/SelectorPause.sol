// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Implementation } from "src/common/Implementation.sol";
import { RoleControl } from "src/dao_access/RoleControl.sol";
import { LibFallbackRouter } from "src/fallback_router/LibFallbackRouter.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

contract SelectorPause is Implementation, RoleControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    error SelectorIsPaused();

    event SelectorPaused(bytes4 indexed selector);
    event SelectorUnpaused(bytes4 indexed selector);
    event ModulePaused(address indexed module);
    event ModuleUnpaused(address indexed module);

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause Module
     * @param module address of the module to pause
     */
    function pauseModule(address module) public onlyRole(ADMIN_ROLE) {
        LibFallbackRouter.Data storage data = _data();
        bytes32[] memory selectors = data.selectors.values();

        for (uint256 i; i < selectors.length; i++) {
            if (
                data.impls[bytes4(selectors[i])] != module ||
                _selectorPaused(bytes4(selectors[i]), data)
            ) continue;
            _pauseSelector(bytes4(selectors[i]), data);
        }

        emit ModulePaused(module);
    }

    /**
     * @notice Unpause Module
     * @param module address of the module to unpause
     */
    function unpauseModule(address module) public onlyRole(ADMIN_ROLE) {
        LibFallbackRouter.Data storage data = _data();
        bytes32[] memory selectors = data.selectors.values();

        for (uint256 i; i < selectors.length; i++) {
            if (
                data.impls[bytes4(selectors[i])] != module ||
                _selectorPaused(bytes4(selectors[i]), data)
            ) continue;
            _unpauseSelector(bytes4(selectors[i]), data);
        }

        emit ModuleUnpaused(module);
    }

    /**
     * @notice Batch functions pause
     * @param selectors array of selectors to pause
     */
    function batchPauseSelectors(bytes4[] memory selectors) public onlyRole(ADMIN_ROLE) {
        LibFallbackRouter.Data storage data = _data();
        for (uint256 i; i < selectors.length; i++) {
            if (_selectorPaused(selectors[i], data)) continue;
            _pauseSelector(selectors[i], data);
        }
    }

    /**
     * @notice Batch functions unpause
     * @param selectors array of selectors to unpause
     */
    function batchUnpauseSelectors(bytes4[] memory selectors) public onlyRole(ADMIN_ROLE) {
        LibFallbackRouter.Data storage data = _data();
        for (uint256 i; i < selectors.length; i++) {
            if (!_selectorPaused(selectors[i], data)) continue;
            _unpauseSelector(selectors[i], data);
        }
    }

    // All selectors, implemented with this contract address, fall here
    // Except those of this contract. Pause functions are always accessible.
    fallback() external {
        revert SelectorIsPaused();
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _pauseSelector(bytes4 selector, LibFallbackRouter.Data storage data) internal {
        address oldImpl = data.impls[selector];

        data.history[selector].push(oldImpl);
        data.impls[selector] = address(this);

        emit SelectorPaused(selector);
    }

    function _unpauseSelector(bytes4 selector, LibFallbackRouter.Data storage data) internal {
        address[] storage historical = _data().history[selector];
        address oldImpl = historical[historical.length - 1];

        data.history[selector].push(address(this));
        data.impls[selector] = oldImpl;

        emit SelectorUnpaused(selector);
    }

    function _selectorPaused(
        bytes4 selector,
        LibFallbackRouter.Data storage data
    ) internal view returns (bool) {
        return (data.impls[selector] == address(this));
    }

    function _data() internal pure returns (LibFallbackRouter.Data storage) {
        return LibFallbackRouter.accessData();
    }
}
