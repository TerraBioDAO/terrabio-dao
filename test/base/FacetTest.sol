// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { BaseTest } from "./BaseTest.t.sol";

import { ArtifactHelper } from "foundry-test-helpers/helper/ArtifactHelper.sol";

import { FallbackRouter } from "src/fallback_router/FallbackRouter.sol";
import { DiamondLoupe } from "src/diamond_retrocompability/DiamondLoupe.sol";
import { LibDaoAccess } from "src/dao_access/LibDaoAccess.sol";
import { ADMIN_ROLE } from "src/dao_access/Roles.sol";

abstract contract FacetTest is BaseTest, ArtifactHelper {
    string facetName;
    string[] functionExceptionIdentifiers;
    address IMPL;

    constructor() {
        functionExceptionIdentifiers.push("fb969b0a"); // bootstrap
    }

    function testSetUp() public {
        assertFalse(isEmptyString(facetName));
        // ⚠️This function will revert if the facet name is not right
        retrieveContractArtifact(facetName);
        // ⚠️This function will revert if the test contract not exists
        retrieveContractTestArtifact(facetName);
    }

    function testOnyAdminCanSet() public {
        string memory artifact = retrieveContractArtifact(facetName);
        ElementAbi[] memory functions = _retrieveFunctionsFromArtifact(artifact);
        delete artifact;
        for (uint i; i < functions.length; i++) {
            if (
                areStringsEquals(functions[i].stateMutability, "view") ||
                areStringsEquals(functions[i].stateMutability, "pure") ||
                isException(functions[i])
            ) continue;

            bytes memory payload = getPayload(functions[i]);

            vm.prank(AN_USER);
            (bool success, bytes memory data) = DAO.call(payload);

            assertFalse(success);
            assertEq(
                data,
                abi.encodeWithSelector(LibDaoAccess.MissingRole.selector, AN_USER, ADMIN_ROLE)
            );
        }
    }

    function getPayload(ElementAbi memory elementAbi) internal pure returns (bytes memory) {
        bytes memory payload;
        payload = bytes.concat(payload, _retrieveSelectorFromElement(elementAbi));
        for (uint i; i < elementAbi.inputs.length; i++) {
            payload = bytes.concat(payload, bytes32(0));
        }
        return payload;
    }

    function isException(ElementAbi memory elementAbi) internal view returns (bool) {
        return
            isContain(
                _methodIdentifierFromSelector(_retrieveSelectorFromElement(elementAbi)),
                functionExceptionIdentifiers
            );
    }

    function retrieveContractArtifact(
        string memory contractName
    ) internal view returns (string memory) {
        string memory path = string.concat("out/", contractName, ".sol/", contractName, ".json");
        return vm.readFile(path);
    }

    function retrieveContractTestArtifact(
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
}
