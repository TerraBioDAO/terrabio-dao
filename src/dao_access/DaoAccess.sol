// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { Implementation } from "src/common/Implementation.sol";
import { LibMembers } from "src/common/LibMembers.sol";
import { ADMIN_ROLE, MEMBER_ROLE } from "./Roles.sol";
import { LibDaoAccess } from "./LibDaoAccess.sol";

/**
 * @title Implementation for AccessControl in the DAO.
 * @dev This contract is an implementation of OZ::IAccessControl
 * (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol),
 * with the logic of Permission Token (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-6366.md).
 */
contract DaoAccess is Implementation {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev address which should call `bootstrap()`
    address private immutable _firstAdmin;

    /**
     * @dev Prevents an address to grant or revoke a role
     * if not authorized.
     */
    modifier onlyAdminRole(bytes32 role) {
        LibDaoAccess.Data storage data = _data();
        bytes32 adminRole = data.adminRole[role];
        bytes32 senderRole = data.roles[msg.sender];

        if (
            // warning with default role 0
            senderRole == 0 ||
            // neither adminRole nor DAO's ADMIN
            (senderRole & adminRole != adminRole && senderRole & ADMIN_ROLE != ADMIN_ROLE)
        ) {
            revert LibDaoAccess.NotRoleOperator(role, adminRole == 0 ? ADMIN_ROLE : adminRole);
        }
        _;
    }

    constructor(address firstAdmin) {
        _firstAdmin = firstAdmin;
    }

    /**
     * @dev permissionless function as delegatecall from the
     * DAO is not authorized (only in constructor)
     */
    function bootstrap() external {
        LibDaoAccess.Data storage data = _data();

        data.roles[_firstAdmin] = ADMIN_ROLE | MEMBER_ROLE;
        LibMembers.accessData().members.add(_firstAdmin);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Grant one or several role to an account.
     * @dev Only ADMIN_ROLE or authorized roles can grant roles,
     * multiple roles can only be granted by the ADMIN_ROLE or if a
     * set of roles are designed to be administered at once.
     *
     * @param role the roles(s) to grant
     * @param account address to assign new role(s)
     */
    function grantRole(bytes32 role, address account) external onlyAdminRole(role) {
        if (!hasRole(role, account)) {
            if (role & MEMBER_ROLE == MEMBER_ROLE) {
                LibMembers.accessData().members.add(account);
            }
            // increment role and store the old value in memory
            bytes32 oldRoles = (_data().roles[account] |= role) ^ role;
            emit LibDaoAccess.RoleUpdated(account, oldRoles, oldRoles | role);
        }
    }

    /**
     * @notice Revoke one or several role to an account.
     * @dev Only ADMIN_ROLE or authorized roles can revoke roles,
     * multiple roles can only be revoked by the ADMIN_ROLE or if a
     * set of roles are designed to be administered at once.
     *
     * @param role the roles(s) to revoke
     * @param account address to assign new role(s)
     */
    function revokeRole(bytes32 role, address account) external onlyAdminRole(role) {
        if (hasRole(role, account)) {
            if (role & MEMBER_ROLE == MEMBER_ROLE) {
                LibMembers.accessData().members.remove(account);
            }
            // decrement role and store the old value in memory
            bytes32 oldRoles = (_data().roles[account] ^= role) | role;
            emit LibDaoAccess.RoleUpdated(account, oldRoles, oldRoles ^ role);
        }
    }

    /**
     * @notice Renounce one or several role to an account.
     * @dev Only ADMIN_ROLE or authorized roles can revoke roles,
     * multiple roles can only be revoked by the ADMIN_ROLE or if a
     * set of roles are designed to be administered at once.
     *
     * @param role the roles(s) to renounce
     * @param account address to assign new role(s)
     */
    function renounceRole(bytes32 role, address account) external {
        if (account != msg.sender) revert LibDaoAccess.NotSelfRenouncement();
        bytes32 oldRoles = (_data().roles[account] ^= role) | role;
        emit LibDaoAccess.RoleUpdated(account, oldRoles, oldRoles ^ role);
    }

    /**
     * @notice Assign an admin role to one or several roles.
     * @dev Only ADMIN_ROLE is authorized to use this function.
     *
     * @param role the roles(s) to be administered
     * @param operatorRole new operator role(s) for `role`
     */
    function setAdminRole(bytes32 role, bytes32 operatorRole) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert LibDaoAccess.MissingRole(msg.sender, ADMIN_ROLE);
        }
        bytes32 oldAdminRole = _data().adminRole[role];
        _data().adminRole[role] = operatorRole;
        emit LibDaoAccess.RoleAdminUpdated(role, oldAdminRole, operatorRole);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                    GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @return true is `account` has `role`
    function hasRole(bytes32 role, address account) public view returns (bool) {
        if (role == 0x0) revert LibDaoAccess.RoleZeroChecked();
        return _data().roles[account] & role == role;
    }

    /// @return operator role for the `role`
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
