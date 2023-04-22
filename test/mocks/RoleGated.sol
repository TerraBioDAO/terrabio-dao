// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ADMIN_ROLE} from "src/dao_access/Roles.sol";
import {RoleControl} from "src/dao_access/RoleControl.sol";

contract RoleGated is RoleControl {
    function gate(bytes32 role) public onlyRole(role) returns (bool) {
        return true;
    }

    function adminGate() public onlyRole(ADMIN_ROLE) returns (bool) {
        return true;
    }
}
