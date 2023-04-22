// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {Implementation} from "src/common/Implementation.sol";
import {LibMembers} from "src/common/LibMembers.sol";
import {ADMIN_ROLE, MEMBER_ROLE} from "./Roles.sol";
import {LibDaoAccess} from "./LibDaoAccess.sol";

contract DaoAccess is Implementation {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private immutable _firstAdmin;

    modifier onlyAdminRole(bytes32 role) {
        LibDaoAccess.Data storage data = _data();
        bytes32 adminRole = data.adminRole[role];
        bytes32 senderRole = data.roles[msg.sender];

        // warning with default role 0
        if (
            senderRole == 0 ||
            (senderRole & adminRole != adminRole &&
                senderRole & ADMIN_ROLE != ADMIN_ROLE)
        )
            revert LibDaoAccess.NotRoleOperator(
                role,
                adminRole == 0 ? ADMIN_ROLE : adminRole
            );
        _;
    }

    constructor(address firstAdmin) {
        _firstAdmin = firstAdmin;
    }

    function bootstrap() external {
        LibDaoAccess.Data storage data = _data();

        data.roles[_firstAdmin] = ADMIN_ROLE | MEMBER_ROLE;
        LibMembers.accessData().members.add(_firstAdmin);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function grantRole(
        bytes32 role,
        address account
    ) external onlyAdminRole(role) {
        if (!hasRole(role, account)) {
            if (role & MEMBER_ROLE == MEMBER_ROLE) {
                LibMembers.accessData().members.add(account);
            }
            _data().roles[account] |= role;
        }
    }

    function revokeRole(
        bytes32 role,
        address account
    ) external onlyAdminRole(role) {
        if (hasRole(role, account)) {
            if (role & MEMBER_ROLE == MEMBER_ROLE) {
                LibMembers.accessData().members.remove(account);
            }
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
