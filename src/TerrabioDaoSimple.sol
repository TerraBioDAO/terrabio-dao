// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import { LibFallbackRouter } from "./fallback_router/LibFallbackRouter.sol";

/**
 * @title Unique storage contract for the DAO system
 * @dev This contract contains only the execution logic for addressing the
 * contract implementation associated with the `calldata`'s selector.
 * This contract is a simplified version of `TerrabioDao` to illustrate
 * how this contract work. This contract will not be used in the DAO system.
 */

contract TerrabioDao {
    constructor(address daoAccess, address fallbackRouter) {
        (bool success, ) = daoAccess.delegatecall(abi.encodeWithSignature("bootstrap()"));
        if (!success) revert("DaoAccess: Incorrect bootstrap");

        (success, ) = fallbackRouter.delegatecall(abi.encodeWithSignature("bootstrap()"));
        if (!success) revert("Router: Incorrect bootstrap");
    }

    receive() external payable {}

    fallback() external payable {
        mapping(bytes4 => address) storage impls = LibFallbackRouter.accessData().impls;

        bytes4 selector = bytes4(msg.data);
        address impl = impls[selector];

        if (impl == address(0)) revert LibFallbackRouter.NotImplemented(selector);

        (bool success, bytes memory resultData) = impl.delegatecall(msg.data);

        if (!success) _revertWithData(resultData);

        _returnWithData(resultData);
    }

    /// @dev Return with arbitrary bytes.
    /// @param data Return data.
    function _returnWithData(bytes memory data) private pure {
        assembly {
            return(add(data, 32), mload(data))
        }
    }

    /// @dev Revert with arbitrary bytes.
    /// @param data Revert data.
    function _revertWithData(bytes memory data) private pure {
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}
