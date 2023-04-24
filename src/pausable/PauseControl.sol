// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {LibPausable} from "./LibPausable.sol";

abstract contract PauseControl {
    /**
     * @dev Modifier to make a function callable only when the DAO is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!LibPausable.accessData().paused, LibPausable.Paused());
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the DAO is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(LibPausable.accessData().paused, LibPausable.NotPaused())
        _;
    }
}
