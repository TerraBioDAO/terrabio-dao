// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { LibDaoAccess } from "./LibDaoAccess.sol";
import { IDaoAccess } from "./IDaoAccess.sol";

abstract contract RoleControl {
    /**
     * @dev Prevents an account to use a function if it
     * hasn't the `role`
     *
     * @param role the role allowed
     */
    modifier onlyRole(bytes32 role) {
        bytes32 senderRole = LibDaoAccess.accessData().roles[msg.sender];

        // NOTE Cannot use this modifier for multiple role:
        // user has one of (A|B) roles => not possible yet

        if (senderRole == 0 || senderRole & role != role)
            revert LibDaoAccess.MissingRole(msg.sender, role);
        _;
    }
}
