// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { LibPausable } from "./LibPausable.sol";

abstract contract PauseControl {
    /**
     * @dev Modifier to make a function callable only when the DAO is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        if (LibPausable.accessData().paused) revert LibPausable.AlreadyPaused();
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
        if (!LibPausable.accessData().paused) revert LibPausable.NotPaused();
        _;
    }
}
