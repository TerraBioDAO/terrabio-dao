// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract Callable {
    uint256 public ping;

    function pingMe(uint256 nb) external returns (bool) {
        ping = nb;
        return true;
    }
}
