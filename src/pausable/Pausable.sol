// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Implementation } from "src/common/Implementation.sol";
import { RoleControl } from "src/dao_access/RoleControl.sol";
import { PauseControl } from "./PauseControl.sol";

import { LibPausable } from "./LibPausable.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";

/**
 * Security module
 * @title To stop the DAO at any moment.
 */
contract Pausable is Implementation, RoleControl, PauseControl {
    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/
    /**
     * Pause DAO
     *
     * Requirements:
     * - Caller must have Admin role
     * - The contract must not be paused.
     */
    function pause() external onlyRole(ADMIN_ROLE) whenNotPaused {
        _data().paused = true;
        emit LibPausable.Paused(msg.sender);
    }

    /**
     * Unpause DAO
     *
     * Requirements:
     * - Caller must have Admin role
     * - The contract must be paused.
     */
    function unpause() external onlyRole(ADMIN_ROLE) whenPaused {
        _data().paused = false;
        emit LibPausable.Unpaused(msg.sender);
    }

    /**
     * Returns paused state.
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        assert(true);
        return _data().paused;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _data() internal pure returns (LibPausable.Data storage) {
        return LibPausable.accessData();
    }
}
