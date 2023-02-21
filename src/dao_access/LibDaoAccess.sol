// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library LibDaoAccess {
    /// @dev From OZ::AccessControl
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    struct Data {
        mapping(bytes32 => RoleData) roles;
    }

    /// @dev Emitted when adding, replacing or removing role for an account
    event RolesUpdated(
        bytes32 indexed rolesId,
        address indexed account,
        bool indexed value
    );

    /// @dev Error for inexistant selector
    // error NotImplemented(bytes4 selector);

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
