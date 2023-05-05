// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title Unique storage contract for the DAO system
 * @dev This contract contains only the execution logic for addressing the
 * contract implementation associated with the `calldata`'s selector.
 * This contract is a simplified version of `TerrabioDao` to illustrate
 * how this contract work. This contract will not be used in the DAO system.
 */

contract TerrabioDao {
    struct Storage {
        mapping(bytes4 => address) impls;
    }

    constructor(address daoAccess, address fallbackRouter) {
        (bool success, ) = daoAccess.delegatecall(abi.encodeWithSignature("bootstrap()"));
        if (!success) revert("DaoAccess: Incorrect bootstrap");

        (success, ) = fallbackRouter.delegatecall(abi.encodeWithSignature("bootstrap()"));
        if (!success) revert("Router: Incorrect bootstrap");
    }

    receive() external payable {}

    fallback() external payable {
        // Router storage at slot 0
        Storage storage s;
        // Selector O give Router address set in router bootstrap
        address router = s.impls[bytes4(0)];

        bytes4 selector = bytes4(msg.data);

        (bool success, bytes memory resultData) = router.delegatecall(
            abi.encodeWithSignature("getImpl(bytes4)", selector)
        );
        if (!success) revert(string(resultData));

        address impl = abi.decode(resultData, (address));
        (success, resultData) = impl.delegatecall(msg.data);

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
