// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { Test, Vm, stdJson, console, console2 } from "forge-std/Test.sol";
import { BaseTest } from "test/base/BaseTest.t.sol";

import { SelectorPause } from "src/pausable/SelectorPause.sol";
import { DaoAccess } from "src/dao_access/DaoAccess.sol";
import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";
import { DiamondLoupe } from "src/diamond_retrocompability/DiamondLoupe.sol";
import { Governance } from "src/governance/Governance.sol";
import { Pausable } from "src/pausable/Pausable.sol";

import { LibDaoAccess } from "src/dao_access/LibDaoAccess.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";

contract Security_test is BaseTest {
    using stdJson for string;
    string[] contractsNames;

    struct FunctionData {
        bytes4 selector;
        address impl;
    }

    struct SubElementAbi {
        string internalType;
        string name;
        string type_;
    }

    struct ElementAbi {
        SubElementAbi[] inputs;
        string name;
        SubElementAbi[] outputs;
        string stateMutability;
        string type_;
    }

    struct AbiStruct {
        ElementAbi[] elements;
    }

    function setUp() public {
        _newUsersSet(0, 4);
        _deployFullDAO(USERS);

        contractsNames.push("Pausable");
        contractsNames.push("SelectorPause");
    }

    function test_only_admin_can_modify_storage() public {
        vm.prank(AN_USER);
        bytes4[] memory selectors = FallbackRouter(DAO).getSelectorList();

        emit log_named_uint("selectors.length", selectors.length);

        FunctionData[] memory functionsData = new FunctionData[](selectors.length);

        for (uint i; i < selectors.length; i++) {
            vm.prank(AN_USER);
            address impl = FallbackRouter(DAO).getFunctionImpl(selectors[i]);
            //emit log_named_bytes32("selector", bytes32(selectors[i]));
            //emit log_named_address("impl", impl);
            functionsData[i] = FunctionData(selectors[i], impl);
        }

        ElementAbi[] memory functions = _retrieveFunctionsFromAbi("Pausable");
        for (uint i; i < functions.length; i++) {
            emit log_named_string("elements[i].name", functions[i].name);
            emit log_named_string("elements[i].stateMutability", functions[i].stateMutability);
        }

        string[] memory ids = _retrieveSelectors("Pausable");
        for (uint i; i < ids.length; i++) {
            emit log_named_string("ids[i]", ids[i]);
        }

        for (uint i; i < functionsData.length; i++) {
            emit log_string(vm.toString(functionsData[i].selector));
        }
    }

    function _retrieveFunctionsFromAbi(
        string memory contractName
    ) internal view returns (ElementAbi[] memory) {
        string memory path = string.concat("out/", contractName, ".sol/", contractName, ".json");
        string memory json = vm.readFile(path);
        bytes memory functions = json.parseRaw('.abi.[?(@.type == "function")]');
        return abi.decode(functions, (ElementAbi[]));
    }

    function _retrieveSelectors(
        string memory contractName
    ) internal view returns (string[] memory) {
        string memory path = string.concat("out/", contractName, ".sol/", contractName, ".json");
        string memory json = vm.readFile(path);
        bytes memory functions = json.parseRaw(".methodIdentifiers.*");
        return abi.decode(functions, (string[]));
    }
}
