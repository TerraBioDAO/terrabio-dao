// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "src/fallback_router/LibFallbackRouter.sol";
import "./IDiamondLoupe.sol";

contract DiamondLoupe is IDiamondLoupe {
    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        LibFallbackRouter.Data storage data = LibFallbackRouter.accessData();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds
                .facetFunctionSelectors[facetAddress_]
                .functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetFunctionSelectors_ = ds
            .facetFunctionSelectors[_facet]
            .functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses()
        external
        view
        override
        returns (address[] memory facetAddresses_)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector)
        external
        view
        override
        returns (address facetAddress_)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = ds
            .selectorToFacetAndPosition[_functionSelector]
            .facetAddress;
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId)
        external
        view
        override
        returns (bool)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.supportedInterfaces[_interfaceId];
    }

    function _selectorsLookup(LibFallbackRouter.Data storage data)
        internal
        view
        returns (bytes4[] memory selectors, address[] memory impls)
    {
        // define number of implementation (facets)
        address[200] memory addresses;
        uint256 length = data.selectors.length();
        uint256 numberOfImpls;
        for (uint256 i; i < length; ) {
            address impl = data.impl[data.selectors.at(i)];
            if (_checkForExistantImpl(addresses, impl, numberOfImpls)) {
                addresses[numberOfImpls++] = impl;
            }
            unchecked {
                ++i;
            }
        }

        impls = new address[](numberOfImpls);
        Facet[] memory facets = new Facet[](numberOfImpls);
        for (uint256 i; i < numberOfImpls; ) {
            facets[i].facetAddress = impls[i];
            for (uint256 j; j < length; ) {}
        }
    }

    function _checkForExistantImpl(
        address[200] addresses,
        address impl,
        uint256 limit
    ) internal pure returns (bool isExistant) {
        for (uint256 i; i < limit; ) {
            if (addresses[i] == impl) {
                isExistant = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    // struct Facet {
    //     address facetAddress;
    //     bytes4[] functionSelectors;
    // }
}
