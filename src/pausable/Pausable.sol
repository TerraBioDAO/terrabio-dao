// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Pausable as OZPausable } from "openzeppelin-contracts/security/Pausable.sol";

import { ADMIN_ROLE } from "src/dao_access/Roles.sol";
import { RoleControl } from "src/dao_access/RoleControl.sol";
import { Implementation } from "src/common/Implementation.sol";
import { LibPausable } from "./LibPausable.sol";

/**
 * @title Implementation for Pausable in the DAO.
 * @dev This contract is an implementation of OZ Pausable
 */
contract Pausable is OZPausable, Implementation, RoleControl {
    constructor() {
        _pause();
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function bootstrap() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function paused() public view override returns (bool) {
        return _data.paused;
    }

    function _pause() internal override whenNotPaused {
        _data.paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal override whenPaused {
        _data.paused = false;
        emit Unpaused(_msgSender());
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _data() internal pure returns (LibPausable.Data storage) {
        return LibPausable.accessData();
    }
}
