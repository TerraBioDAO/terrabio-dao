// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

/**
 * @title Library for events, errors, data layout and storage location
 * related to `Pausable`
 * @dev Give more details about Libs
 */

library LibPausable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address indexed account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address indexed account);

    error AlreadyPaused();
    error NotPaused();

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                LAYOUT
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    struct Data {
        bool paused;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                            STORAGE LOCATION
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @dev Storage slot for Data struct
    bytes32 internal constant STORAGE_SLOT = keccak256("terrabiodao.contracts.storage.Pausable.v1");

    /// @return data Data struct at `STORAGE_SLOT`
    function accessData() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}
