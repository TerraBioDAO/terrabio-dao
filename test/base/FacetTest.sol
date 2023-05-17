// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { BaseTest } from "./BaseTest.t.sol";

import { ArtifactHelper } from "test/base/ArtifactHelper.sol";

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
        _retrieveContractJsonFromArtifact(facetName);
        // ⚠️This function will revert if the test contract not exists
        _retrieveContractTestJsonFromArtifact(facetName);
    }

    function testOnyAdminCanSet() public {
        string memory artifact = _retrieveContractJsonFromArtifact(facetName);
        string memory methodIdentifierJson = _retrieveMethodIdentifierJsonFromArtifact(artifact);
        ElementAbi[] memory functions = _retrieveFunctionsFromArtifact(artifact);
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

    /*function testOnyAdminCanSet2() public {
        vm.prank(AN_USER);
        bytes4[] memory selectors = FallbackRouter(DAO).getSelectorList();
        //bytes4[] memory selectors = DiamondLoupe(DAO).facetFunctionSelectors(IMPL);
        string[] memory methodIdentifiers = new string[](selectors.length);
        string memory artifact = _retrieveContractJsonFromArtifact(facetName);
        string memory methodIdentifierJson = _retrieveMethodIdentifierJsonFromArtifact(artifact);
        ElementAbi[] memory functions = _retrieveFunctionsFromArtifact(artifact);
        string[] memory functionSignatures = new string[](functions.length);
        for (uint i; i < functions.length; i++) {
            functionSignatures[i] = _retrieveSignatureFromElement(functions[i]);
            //emit log_named_string("signature", functionSignatures[i]);
        }

        for (uint i; i < selectors.length; i++) {
            methodIdentifiers[i] = _methodIdentifierFromSelector(selectors[i]);
            methods[methodIdentifiers[i]].selector = selectors[i];
            methods[methodIdentifiers[i]].impl = FallbackRouter(DAO).getFunctionImpl(selectors[i]);
            methods[methodIdentifiers[i]].signature = _retrieveSignatureFromArtifact(
                methodIdentifierJson,
                methodIdentifiers[i]
            );
            //emit log_named_string("signature", methods[methodIdentifiers[i]].signature);

            methods[methodIdentifiers[i]].functionId = retrieveFunctionId(
                methods[methodIdentifiers[i]].signature,
                functionSignatures
            );
            //emit log_named_uint("functionId", methods[methodIdentifiers[i]].functionId);
        }

        //emit log_named_uint("retrieved selectors from Router", selectors.length);

        string[] memory ids = _retrieveMethodIdentifiersFromArtifact(artifact);
        ids = _filterMethodIdentifiers(ids, functionExceptionIdentifiers);

        // Selectors have the same facet implementation
        for (uint i = 0; i < ids.length; i++) {
            assertEq(IMPL, methods[ids[i]].impl);
        }

        // Test if all ids are in the method identifiers list construct from selectors list.
        assertLe(ids.length, methodIdentifiers.length);
        for (uint i; i < ids.length; i++) {
            assertTrue(isArrayContain(ids[i], methodIdentifiers));
        }

        // Test that all functions (except exceptions) that change Storage have onlyAdmin requirement
        for (uint i; i < ids.length; i++) {
            uint functionId = methods[ids[i]].functionId;

            if (
                areStringsEquals(functions[functionId].stateMutability, "view") ||
                areStringsEquals(functions[functionId].stateMutability, "pure")
            ) continue;

//            emit log_named_string("functionIdentifier", ids[i]);
//            emit log_named_uint("functionId", functionId);
//            emit log_named_bytes32("selector", methods[ids[i]].selector);
//            emit log_named_string("signature", methods[ids[i]].signature);
//            emit log_named_address("impl", methods[ids[i]].impl);

            bytes memory payload = getPayload(ids[i], functions[functionId]);

            vm.prank(AN_USER);
            (bool success, bytes memory data) = DAO.call(payload);

            assertFalse(success);
            assertEq(
                data,
                abi.encodeWithSelector(LibDaoAccess.MissingRole.selector, AN_USER, ADMIN_ROLE)
            );
        }

        // Uncomment next line to see all inputTypes
        //_setInputTypesFromArtifact(artifact);
    }*/

    function getPayload(ElementAbi memory elementAbi) internal view returns (bytes memory) {
        bytes memory payload;
        payload = bytes.concat(payload, _retrieveSelectorFromElement(elementAbi));
        for (uint i; i < elementAbi.inputs.length; i++) {
            payload = bytes.concat(payload, bytes32(0));
        }
        return payload;
    }

    function getPayload(
        string memory functionIdentifier,
        ElementAbi memory elementAbi
    ) internal view returns (bytes memory) {
        bytes memory payload;
        payload = bytes.concat(payload, methods[functionIdentifier].selector);
        for (uint i; i < elementAbi.inputs.length; i++) {
            payload = bytes.concat(payload, bytes32(0));
        }
        return payload;
    }

    function retrieveFunctionId(
        string memory signature,
        string[] memory functionSignatures
    ) internal pure returns (uint) {
        for (uint i; i < functionSignatures.length; i++) {
            if (areStringsEquals(signature, functionSignatures[i])) return i;
        }

        return 1000;
    }

    function isException(ElementAbi memory elementAbi) internal returns (bool) {
        return
            isArrayContain(
                _methodIdentifierFromSelector(_retrieveSelectorFromElement(elementAbi)),
                functionExceptionIdentifiers
            );
    }
}
