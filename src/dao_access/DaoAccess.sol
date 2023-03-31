// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Implementation} from "src/common/Implementation.sol";
import {ADMIN_ROLE} from "src/dao_access/Roles.sol";
import {LibDaoAccess} from "./LibDaoAccess.sol";

contract DaoAccess is Implementation {
    address private immutable _firstAdmin;

    modifier onlyAdminRole(bytes32 role) {
        LibDaoAccess.Data storage data = _data();
        bytes32 adminRole = ADMIN_ROLE | data.adminRole[role];
        bytes32 senderRole = data.roles[msg.sender];

        // warning with default role 0
        if (senderRole == 0 || senderRole & adminRole != senderRole)
            revert LibDaoAccess.NotRoleOperator(role, adminRole);
        _;
    }

    constructor(address firstAdmin) {
        _firstAdmin = firstAdmin;
    }

    function bootstrap() external {
        LibDaoAccess.Data storage data = _data();

        data.roles[_firstAdmin] = ADMIN_ROLE;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function grantRole(
        bytes32 role,
        address account
    ) external onlyAdminRole(role) {
        if (!hasRole(role, account)) {
            _data().roles[account] |= role;
        }
    }

    function revokeRole(
        bytes32 role,
        address account
    ) external onlyAdminRole(role) {
        if (hasRole(role, account)) {
            _data().roles[account] ^= role;
        }
    }

    function renounceRole(bytes32 role, address account) external {
        if (account != msg.sender) revert LibDaoAccess.NotSelfRenouncement();
        _data().roles[account] ^= role;
    }

    /// @dev assign an admin role for a specific role
    function setAdminRole(bytes32 role, bytes32 operator) external {
        if (!hasRole(ADMIN_ROLE, msg.sender))
            revert LibDaoAccess.MissingRole(msg.sender, ADMIN_ROLE);
        _data().adminRole[role] = operator;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                    GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function hasRole(bytes32 role, address account) public view returns (bool) {
        if (role == 0x0) revert LibDaoAccess.RoleZeroChecked();
        return _data().roles[account] & role == role;
    }

    function getRoleAdmin(bytes32 role) external view returns (bytes32) {
        return _data().adminRole[role];
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _data() internal pure returns (LibDaoAccess.Data storage) {
        return LibDaoAccess.accessData();
    }
}
