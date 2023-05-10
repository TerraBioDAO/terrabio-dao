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
    constructor(address daoAccess, address fallbackRouter) {
        (bool success, ) = daoAccess.delegatecall(abi.encodeWithSignature("bootstrap()"));
        if (!success) revert("DaoAccess: Incorrect bootstrap");

        (success, ) = fallbackRouter.delegatecall(abi.encodeWithSignature("bootstrap()"));
        if (!success) revert("Router: Incorrect bootstrap");
    }

    receive() external payable {}

    fallback() external payable {
        // address router slot : impls[bytes4(0)]
        bytes32 slot = 0x8ce8d4b76d0c9196e0b9098a911177217a2ae6c4a38ec5853bbb73f5b868698a;
        address router;
        assembly {
            router := sload(slot)
        }

        (bool success, bytes memory resultData) = router.delegatecall(
            abi.encodeWithSignature("execute(bytes)", msg.data)
        );
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
