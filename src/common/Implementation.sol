// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

abstract contract Implementation {
    address internal immutable IMPL_ADDR;

    constructor() {
        IMPL_ADDR = address(this);
    }
}
