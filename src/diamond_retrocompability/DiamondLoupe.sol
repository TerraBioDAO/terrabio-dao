// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import "src/utils/DynamicalMemoryArray.sol";
import "src/fallback_router/LibFallbackRouter.sol";
import "./IDiamondLoupe.sol";

contract DiamondLoupe is IDiamondLoupe {
    using DynamicalMemoryArray for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_) {
        LibFallbackRouter.Data storage data = LibFallbackRouter.accessData();
        return _createFacets(data);
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet)
        external
        view
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        LibFallbackRouter.Data storage data = LibFallbackRouter.accessData();
        Facet[] memory facets_ = _createFacets(data);
        for (uint256 i; i < facets_.length; ) {
            if (facets_[i].facetAddress == _facet) {
                return facets_[i].functionSelectors;
            }
        }
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory) {
        LibFallbackRouter.Data storage data = LibFallbackRouter.accessData();
        Facet[] memory facets_ = _createFacets(data);
        address[] memory facetAddresses_ = new address[](facets_.length);
        for (uint256 i; i < facets_.length; ) {
            facetAddresses_[i] = facets_[i].facetAddress;
        }
        return facetAddresses_;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector)
        external
        view
        returns (address facetAddress_)
    {
        return LibFallbackRouter.accessData().impls[_functionSelector];
    }

    function _createFacets(LibFallbackRouter.Data storage data)
        internal
        view
        returns (Facet[] memory facets_)
    {
        uint256 length = data.selectors.length();
        uint256 impls_key = DynamicalMemoryArray.create(200);

        for (uint256 i; i < length; ) {
            // read addr impl
            bytes4 selector = bytes4(data.selectors.at(i));
            address impl = data.impls[selector];

            // create key for address
            uint256 selectors_key = uint160(impl) & 0xFFFF;

            // get number of selector added
            uint256 selectorsAdded = selectors_key.length();

            // check if impl is known
            if (selectorsAdded == 0) {
                selectors_key.createAt();
                impls_key.push(uint160(impl));
            }

            // push selector
            selectors_key.push(uint32(selector));

            // loop
            unchecked {
                ++i;
            }
        }

        // read memory and create facets
        uint256 nbOfImpls = impls_key.length();
        facets_ = new Facet[](nbOfImpls);

        for (uint256 i; i < nbOfImpls; ) {
            address impl = address(uint160(impls_key.at(i)));
            uint256 selectors_key = uint160(impl) & 0xFFFF;

            bytes4[] memory selectors = new bytes4[](selectors_key.length());
            for (uint256 j; j < selectors_key.length(); ) {
                selectors[j] = bytes4(uint32(selectors_key.at(j)));
                unchecked {
                    ++j;
                }
            }

            facets_[i] = Facet({
                facetAddress: impl,
                functionSelectors: selectors
            });

            unchecked {
                ++i;
            }
        }
    }
}
