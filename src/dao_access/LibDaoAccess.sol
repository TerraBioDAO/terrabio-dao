// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title Library for events, errors, data layout and storage location
 * related to `DaoAccess`
 * @dev Give more details about Libs
 */

library LibDaoAccess {
    /// @dev Emitted when adding, replacing or removing role for an account
    event RoleUpdated(
        address indexed account,
        bytes32 indexed fromRoles,
        bytes32 indexed toRoles
    );

    event RoleAdminUpdated(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed adminRole
    );

    /// @dev Role's related errors
    error RoleZeroChecked();
    error NotSelfRenouncement();
    error NotRoleOperator(bytes32 role, bytes32 operator);
    error MissingRole(address caller, bytes32 role);

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                LAYOUT
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    struct Data {
        mapping(address => bytes32) roles;
        mapping(bytes32 => bytes32) adminRole;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                            STORAGE LOCATION
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @dev Storage slot for Data struct
    bytes32 internal constant STORAGE_SLOT =
        keccak256("terrabiodao.contracts.storage.DaoAccess.v1");

    /// @return data Data struct at `STORAGE_SLOT`
    function accessData() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}
