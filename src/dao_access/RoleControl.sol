// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {LibDaoAccess} from "./LibDaoAccess.sol";
import {IDaoAccess} from "./IDaoAccess.sol";

abstract contract RoleControl {
    modifier onlyRole(bytes32 role) {
        if (LibDaoAccess.accessData().roles[msg.sender] & role != role)
            revert LibDaoAccess.MissingRole(msg.sender, role);
        _;
    }
}
