// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

contract UtilsTest is Test {
    using Strings for uint160;

    // default values
    bytes4 internal SELECTOR_0;

    // roles
    address internal constant OWNER = address(501);
    address[] internal USERS;

    function _newUsersSet(uint160 offset, uint256 length) internal {
        address[] memory list = new address[](length);

        for (uint160 i; i < length; i++) {
            vm.deal(address(i + offset + 1), 100 ether);
            list[i] = address(i + offset + 1);
            vm.label(address(i + offset + 1), string.concat("USER", (i + offset + 1).toString()));
        }
        USERS = list;
    }
}
