// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

/**
 * @notice Utils to store implementation address
 * @dev Can be useful to restrict access from only-delegatecall or only-call
 */
abstract contract Implementation {
    address internal immutable IMPL_ADDR;

    constructor() {
        IMPL_ADDR = address(this);
    }
}
