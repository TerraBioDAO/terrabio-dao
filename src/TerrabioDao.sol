// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {LibFallbackRouter} from "./fallback_router/LibFallbackRouter.sol";

contract TerrabioDao {
    constructor(address daoAccess, address fallbackRouter) {
        (bool success, ) = daoAccess.delegatecall(
            abi.encodeWithSignature("bootstrap()")
        );
        if (!success) revert("DaoAccess: Incorrect bootstrap");

        (success, ) = fallbackRouter.delegatecall(
            abi.encodeWithSignature("bootstrap()")
        );
        if (!success) revert("Router: Incorrect bootstrap");
    }

    /// @dev Forwards calls to the appropriate implementation contract.
    fallback() external payable {
        // This is used in assembly below as impls.slot.
        mapping(bytes4 => address) storage impls = LibFallbackRouter
            .accessData()
            .impls;

        assembly {
            let cdlen := calldatasize()

            // equivalent of receive() external payable {}
            if iszero(cdlen) {
                return(0, 0)
            }

            // Store at 0x40, to leave 0x00-0x3F for slot calculation below.
            calldatacopy(0x40, 0, cdlen)
            let selector := and(
                mload(0x40),
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            )

            // Slot for impls[selector] is keccak256(selector . impls_slot).
            mstore(0, selector)
            mstore(0x20, impls.slot)
            let slot := keccak256(0, 0x40)

            let delegate := sload(slot)
            if iszero(delegate) {
                // Revert with:
                // abi.encodeWithSelector(
                //   bytes4(keccak256("NotImplementedError(bytes4)")),
                //   selector)
                mstore(
                    0,
                    0x734e6e1c00000000000000000000000000000000000000000000000000000000
                )
                mstore(4, selector)
                revert(0, 0x24)
            }

            let success := delegatecall(gas(), delegate, 0x40, cdlen, 0, 0)
            let rdlen := returndatasize()
            returndatacopy(0, 0, rdlen)
            if success {
                return(0, rdlen)
            }
            revert(0, rdlen)
        }
    }
}
