// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract ContractRegistry is Ownable {
    event Whitelisted(address indexed addr, address setter);

    mapping(address => bool) private _whitelisted;
    mapping(address => bool) private _proposedAddr;

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    function whitelistAddr(address addr) external onlyOwner {
        require(addr != address(0), "Address zero");
        _whitelisted[addr] = true;
        emit Whitelisted(addr, msg.sender);
    }

    function proposeAddr(address addr) external {
        _proposedAddr[addr] = true;
    }

    function isWhitelisted(address addr) external view returns (bool) {
        return _whitelisted[addr];
    }
}
