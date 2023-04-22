// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {LibDaoAccess} from "./LibDaoAccess.sol";
import {IDaoAccess} from "./IDaoAccess.sol";

abstract contract RoleControl {
    modifier onlyRole(bytes32 role) {
        bytes32 senderRole = LibDaoAccess.accessData().roles[msg.sender];

        // Gate for multiple role: user has one of (A|B) roles => not possible yet

        if (senderRole == 0 || senderRole & role != role)
            revert LibDaoAccess.MissingRole(msg.sender, role);
        _;
    }
}
