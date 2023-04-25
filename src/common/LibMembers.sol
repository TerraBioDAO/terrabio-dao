// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

library LibMembers {
    using EnumerableSet for EnumerableSet.AddressSet;

    event MembersUpdated(address indexed account, bool indexed isEntry);

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                                LAYOUT
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    struct Data {
        EnumerableSet.AddressSet members;
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                            STORAGE LOCATION
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @dev Storage slot for Data struct
    bytes32 internal constant STORAGE_SLOT =
        keccak256("terrabiodao.contracts.storage.Members.v1");

    /// @return data Data struct at `STORAGE_SLOT`
    function accessData() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}
