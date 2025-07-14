// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title ErrorHandler
/// @notice Inherit to safely call external targets with optional error bubbling.
abstract contract ErrorHandler {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev Thrown when attempting to register an already-registered selector.
    error ErrorAlreadyRegistered(address target, bytes4 selector);
    /// @dev Thrown when attempting to unregister a non-registered selector.
    error ErrorNotRegistered(address target, bytes4 selector);

    /// @notice A registry to manage critical errors for a single consumer.
    struct ErrorRegistry {
        // A set of registered error selectors for efficient add, remove, and contains checks.
        EnumerableSet.Bytes32Set selectors;
        // Mapping from a selector back to its original signature string for observability.
        mapping(bytes4 => string) selectorToStrings;
    }

    /// @notice Maps each target address to its dedicated error registry.
    mapping(address => ErrorRegistry) private registries;

    event ErrorRegistered(
        address indexed target,
        bytes4 errorSelector,
        string errorSignature
    );
    event ErrorUnregistered(address indexed target, bytes4 errorSelector);
    event DeliverySuccess(address indexed target);
    event TargetError(address indexed target, bytes data);

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
                if (registries[target].selectors.contains(bytes32(sel))) {
                    assembly {
                        revert(add(data, 32), mload(data))
                    }
                }
            }
            emit TargetError(target, data);
        }
    }

    /// @notice Register an error selector for a target.
    function _registerError(address target, string calldata fsigStr) internal {
        bytes4 sel = stringToFsig(fsigStr);
        ErrorRegistry storage registry = registries[target];
        if (!registry.selectors.add(bytes32(sel))) {
            revert ErrorAlreadyRegistered(target, sel);
        }
        registry.selectorToStrings[sel] = fsigStr;
        emit ErrorRegistered(target, sel, fsigStr);
    }

    /// @notice Unregister an error selector.
    function _unregisterError(
        address target,
        string calldata fsigStr
    ) internal {
        bytes4 sel = stringToFsig(fsigStr);
        ErrorRegistry storage registry = registries[target];
        if (!registry.selectors.remove(bytes32(sel))) {
            revert ErrorNotRegistered(target, sel);
        }
        delete registry.selectorToStrings[sel];
        emit ErrorUnregistered(target, sel);
    }

    /// @notice Get all error selectors for a target.
    function getRegisteredErrorsBytes4(
        address target
    ) external view returns (bytes4[] memory fsigs) {
        bytes32[] memory vals32 = registries[target].selectors.values();
        fsigs = new bytes4[](vals32.length);
        for (uint256 i = 0; i < fsigs.length; i++) {
            fsigs[i] = bytes4(vals32[i]);
        }
    }

    /// @notice Get all error selectors for a target.
    function getRegisteredErrorsString(
        address target
    ) external view returns (string[] memory signatures) {
        bytes32[] memory selectors32 = registries[target].selectors.values();
        signatures = new string[](selectors32.length);
        for (uint256 i = 0; i < selectors32.length; i++) {
            signatures[i] = registries[target].selectorToStrings[
                bytes4(selectors32[i])
            ];
        }
    }

    /// @notice Check if an error selector is registered.
    function isErrorRegistered(
        address target,
        string calldata fsigStr
    ) external view returns (bool) {
        bytes4 sel = stringToFsig(fsigStr);
        return registries[target].selectors.contains(bytes32(sel));
    }

    /// @notice Get the count of registered errors.
    function getRegisteredErrorsCount(
        address target
    ) external view returns (uint256) {
        return registries[target].selectors.length();
    }

    /// @notice Calculate the function signature from string.
    function stringToFsig(
        string calldata fsigStr
    ) public pure returns (bytes4 fsig) {
        fsig = bytes4(keccak256(bytes(fsigStr)));
    }
}
