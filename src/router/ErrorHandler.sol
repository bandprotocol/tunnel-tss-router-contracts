// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IErrorHandler.sol";

/// @title ErrorHandler
/// @notice Inherit to safely call external targets with optional error bubbling.
abstract contract ErrorHandler is IErrorHandler {
    /// @notice Maps each target address to its dedicated error registry.
    mapping(address => mapping(bytes4 => string)) internal registries;

    /// @dev Call target.call(callData). On revert, rethrow if selector registered; else log and continue.
    function _callWithCustomErrorHandling(
        address target,
        uint256 callbackGasLimit,
        bytes memory callData
    ) internal returns (bool ok, bytes memory data) {
        (ok, data) = target.call{gas: callbackGasLimit}(callData);
        if (ok) {
            emit DeliverySuccess(target);
        } else {
            if (data.length >= 4) {
                bytes4 sel;
                assembly {
                    // The selector is the first 4 bytes of the revert data.
                    sel := mload(add(data, 32))
                }
                if (_isErrorRegistered(target, sel)) {
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }
            }
            emit DeliveryError(target, data);
        }
    }

    /// @notice Register an error selector for a target.
    function _registerError(address target, string calldata fsigStr) internal {
        bytes4 sel = stringToFsig(fsigStr);
        if (_isErrorRegistered(target, sel)) {
            revert ErrorAlreadyRegistered(target, sel, fsigStr);
        }
        registries[target][sel] = fsigStr;
        emit ErrorRegistered(target, sel, fsigStr);
    }

    /// @notice Unregister an error selector.
    function _unregisterError(
        address target,
        string calldata fsigStr
    ) internal {
        bytes4 sel = stringToFsig(fsigStr);
        if (!_isErrorRegistered(target, sel)) {
            revert ErrorNotRegistered(target, sel, fsigStr);
        }
        delete registries[target][sel];
        emit ErrorUnregistered(target, sel, fsigStr);
    }

    /// @notice Check if an error selector is registered.
    function _isErrorRegistered(
        address target,
        bytes4 sel
    ) internal view returns (bool isRegistered) {
        isRegistered = bytes(registries[target][sel]).length > 0;
    }

    /// @notice Check if an error selector is registered.
    function isErrorRegistered(
        address target,
        string calldata fsigStr
    ) external view returns (bool isRegistered) {
        isRegistered = _isErrorRegistered(target, stringToFsig(fsigStr));
    }

    /// @notice A helper function for query a registered error.
    function getRegisteredError(
        address target,
        bytes4 sel
    ) external view returns (string memory errorSignature) {
        if (!_isErrorRegistered(target, sel)) {
            revert ErrorNotRegistered(target, sel, "");
        }
        errorSignature = registries[target][sel];
    }

    /// @notice Calculate the function signature from string.
    function stringToFsig(
        string calldata fsigStr
    ) public pure returns (bytes4 fsig) {
        fsig = bytes4(keccak256(bytes(fsigStr)));
    }
}
