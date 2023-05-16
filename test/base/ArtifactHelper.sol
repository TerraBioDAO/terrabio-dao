// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import { StringHelper } from "foundry-test-helpers/helper/StringHelper.sol";

abstract contract ArtifactHelper is StringHelper, Test {
    using stdJson for string;
    // methodIdentifier => data
    mapping(string => FunctionData) methods;

    string[] inputTypes;

    string[] tempStringArray;

    struct FunctionData {
        bytes4 selector;
        address impl;
        string signature;
        uint256 functionId;
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

    function _callData(
        bytes4 selector,
        string[] memory types
    ) internal pure returns (bytes memory) {
        bytes memory callData;
        callData = bytes.concat(callData, selector);
        for (uint i; i < types.length; i++) {
            callData = bytes.concat(callData, bytes32(0));
        }
        return callData;
    }

    function _setInputTypesFromArtifact(string memory json) internal returns (string[] memory) {
        bytes memory typesBytes = json.parseRaw(
            //'$.abi[?(@.type == "function" && (@.stateMutability == "nonpayable" || @.stateMutability == "payable"))].inputs[*].type'
            '$.abi[?(@.type == "function")].inputs[*].type'
        );

        string[] memory types = abi.decode(typesBytes, (string[]));
        delete typesBytes;

        bool isAlreadyPresent;
        uint id;

        if (types.length == 0) return types;
        /*for (uint i = 0; i < inputTypes.length; i++) {
            emit log_string(string.concat("input[", vm.toString(i), "]:", inputTypes[i]));
        }*/
        if (id == 0) inputTypes.push(types[0]);
        id++;
        for (uint i = 1; i < types.length; i++) {
            for (uint j; j < inputTypes.length; j++) {
                if (areStringsEquals(types[i], inputTypes[j])) isAlreadyPresent = true;
            }

            if (!isAlreadyPresent) {
                inputTypes.push(types[i]);
                id++;
            }

            isAlreadyPresent = false;
        }

        emit log_string("All types in this facet");
        for (uint i; i < inputTypes.length; i++) {
            emit log_string(string.concat("input[", vm.toString(i), "]:", inputTypes[i]));
        }

        return inputTypes;
    }

    function _retrieveSelectorFromFunctionIdentifier(
        string memory functionIdentifier
    ) internal view returns (bytes4) {
        return methods[functionIdentifier].selector;
    }

    function _retrieveFunctionsFromArtifact(
        string memory json
    ) internal pure returns (ElementAbi[] memory) {
        bytes memory functions = json.parseRaw('.abi.[?(@.type == "function")]');
        return abi.decode(functions, (ElementAbi[]));
    }

    function _retrieveMethodIdentifiersFromArtifact(
        string memory json
    ) internal pure returns (string[] memory) {
        bytes memory functions = json.parseRaw(".methodIdentifiers.*");
        return abi.decode(functions, (string[]));
    }

    function _filterMethodIdentifiers(
        string[] memory ids,
        string[] memory functionExceptionIdentifiers
    ) internal returns (string[] memory) {
        for (uint i = 0; i < ids.length; i++) {
            // require not an exception
            if (isArrayContain(ids[i], functionExceptionIdentifiers)) continue;

            tempStringArray.push(ids[i]);
        }
        string[] memory identifiers = new string[](tempStringArray.length);
        for (uint i = 0; i < tempStringArray.length; i++) {
            identifiers[i] = tempStringArray[i];
        }

        delete tempStringArray;

        return identifiers;
    }

    function _retrieveMethodIdentifierJsonFromArtifact(
        string memory json
    ) internal pure returns (string memory) {
        uint startPosition = getPositionStringContained("methodIdentifiers", json);
        uint end = findFirstCharPositionAfter("}", startPosition, json);
        return slice(startPosition, end, json);
    }

    function _retrieveSignatureFromArtifact(
        string memory json,
        string memory methodIdentifier
    ) internal pure returns (string memory) {
        if (!isStringContain(methodIdentifier, json)) return "";
        // "signature": "methodIdentifier"
        uint end = getPositionStringContained(methodIdentifier, json) - 5;
        uint startPosition = findFirstCharPositionBefore('"', end, json) + 1;

        return slice(startPosition, end, json);
    }

    function _retrieveSignatureFromElement(
        ElementAbi memory elementAbi
    ) internal pure returns (string memory) {
        string memory signature = string.concat(elementAbi.name, "(");
        if (elementAbi.inputs.length == 0) return string.concat(signature, ")");
        for (uint i; i < elementAbi.inputs.length - 1; i++) {
            signature = string.concat(signature, elementAbi.inputs[i].type_, ",");
        }

        return string.concat(signature, elementAbi.inputs[elementAbi.inputs.length - 1].type_, ")");
    }

    function _methodIdentifierFromSelector(bytes4 selector) internal pure returns (string memory) {
        return slice(3, 10, vm.toString(selector));
    }

    function _retrieveContractJsonFromArtifact(
        string memory contractName
    ) internal view returns (string memory) {
        string memory path = string.concat("out/", contractName, ".sol/", contractName, ".json");
        return vm.readFile(path);
    }

    function _retrieveContractTestJsonFromArtifact(
        string memory contractName
    ) internal view returns (string memory) {
        string memory path = string.concat(
            "out/",
            contractName,
            ".t.sol/",
            contractName,
            "_security_test.json"
        );
        return vm.readFile(path);
    }

    function isArrayContain(string memory what, string[] memory where) public pure returns (bool) {
        for (uint256 i = 0; i < where.length; i++) {
            if (areStringsEquals(where[i], what)) return true;
        }

        return false;
    }

    function isStringContain(string memory what, string memory where) public pure returns (bool) {
        uint256 whatBytesLength = bytes(what).length;
        uint256 whereBytesLength = bytes(where).length;

        for (uint256 i = 0; i <= whereBytesLength - whatBytesLength; i++) {
            if (areStringsEquals(slice(i + 1, i + whatBytesLength, where), what)) return true;
        }

        return false;
    }

    function getPositionStringContained(
        string memory what,
        string memory where
    ) public pure returns (uint256) {
        uint256 whatBytesLength = bytes(what).length;
        uint256 whereBytesLength = bytes(where).length;

        for (uint256 i = 0; i <= whereBytesLength - whatBytesLength; i++) {
            if (areStringsEquals(slice(i + 1, i + whatBytesLength, where), what)) return i + 1;
        }

        return 0;
    }

    function findFirstCharPositionAfter(
        string memory char,
        uint256 startPosition,
        string memory where
    ) public pure returns (uint256) {
        require(bytes(char).length == 1 && startPosition != 0);
        uint256 whereBytesLength = bytes(where).length;

        for (uint256 i = startPosition - 1; i < whereBytesLength - 1; i++) {
            if (areStringsEquals(slice(i + 1, i + 1, where), char)) return i + 1;
        }

        return 0;
    }

    function findFirstCharPositionBefore(
        string memory char,
        uint256 startPosition,
        string memory where
    ) public pure returns (uint256) {
        require(bytes(char).length == 1 && startPosition != 0);

        for (uint256 i = startPosition - 1; i > 0; i--) {
            if (areStringsEquals(slice(i + 1, i + 1, where), char)) return i + 1;
        }

        return 0;
    }
}
