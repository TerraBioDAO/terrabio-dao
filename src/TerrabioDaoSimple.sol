// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {LibFallbackRouter} from "./fallback_router/LibFallbackRouter.sol";

contract TerrabioDao {
    constructor(address daoAccess, address fallbackRouter) {
        (bool success, ) = daoAccess.delegatecall(
            abi.encodeWithSignature("bootstrap()")
        );
        if (!success) revert("DaoAccess: Incorrect bootstrap");

        (success, ) = fallbackRouter.delegatecall(
            abi.encodeWithSignature("bootstrap()")
        );
        if (!success) revert("Router: Incorrect bootstrap");
    }

    receive() external payable {}

    fallback() external payable {
        mapping(bytes4 => address) storage impls = LibFallbackRouter
            .accessData()
            .impls;

        bytes4 selector = bytes4(msg.data);
        address impl = impls[selector];

        if (impl == address(0))
            revert LibFallbackRouter.NotImplemented(selector);

        (bool success, bytes memory resultData) = impl.delegatecall(msg.data);

        if (!success) revert(string(resultData));

        _returnWithData(resultData);
    }

    /// @dev Return with arbitrary bytes.
    /// @param data Return data.
    function _returnWithData(bytes memory data) private pure {
        assembly {
            return(add(data, 32), mload(data))
        }
    }
}
