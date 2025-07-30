// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

/**
 * @title IErrorHandler
 * @notice Interface for a contract that handles external call errors based on a registry.
 */
interface IErrorHandler {
    // ========================================
    // Events
    // ========================================

    /**
     * @notice Emitted when a new error is registered for a target.
     * @param target The address of the target contract.
     * @param errorSelector The 4-byte selector of the registered error.
     * @param errorSignature The full signature string of the error.
     */
    event ErrorRegistered(
        address indexed target,
        bytes4 indexed errorSelector,
        string errorSignature
    );

    /**
     * @notice Emitted when an error is unregistered for a target.
     * @param target The address of the target contract.
     * @param errorSelector The 4-byte selector of the unregistered error.
     * @param errorSignature The full signature string of the error.
     */
    event ErrorUnregistered(
        address indexed target,
        bytes4 indexed errorSelector,
        string errorSignature
    );

    /**
     * @notice Emitted when an external call to a target succeeds.
     * @param target The address of the contract that was successfully called.
     */
    event DeliverySuccess(address indexed target);

    /**
     * @notice Emitted when an external call to a target reverts with an unregistered error.
     * @param target The address of the contract that reverted.
     * @param data The low-level revert data from the failed call.
     */
    event DeliveryError(address indexed target, bytes data);

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Reverts when attempting to register an error that is already registered for a target.
     * @param target The address of the target contract.
     * @param errorSelector The selector of the error that was already registered.
     * @param errorSignature The signature of the error that was already registered.
     */
    error ErrorAlreadyRegistered(
        address target,
        bytes4 errorSelector,
        string errorSignature
    );

    /**
     * @notice Reverts when attempting to get or to unregister an error that is not currently registered.
     * @param target The address of the target contract.
     * @param errorSelector The selector of the error that was not found.
     * @param errorSignature The signature of the error that was not found.
     */
    error ErrorNotRegistered(
        address target,
        bytes4 errorSelector,
        string errorSignature
    );

    // ========================================
    // Functions
    // ========================================

    /**
     * @dev Checks if a specific error is registered for a target.
     * @param target The address of the target contract to check.
     * @param fsigStr The full signature string of the error (e.g., "MyError(uint256)").
     * @return isRegistered True if the error is registered, false otherwise.
     */
    function isErrorRegistered(
        address target,
        string calldata fsigStr
    ) external view returns (bool isRegistered);

    /**
     * @dev Retrieves the signature string for a registered error selector.
     * Reverts if the selector is not registered for the given target.
     * @param target The address of the target contract.
     * @param sel The 4-byte selector of the error.
     * @return errorSignature The full signature string of the registered error.
     */
    function getRegisteredError(
        address target,
        bytes4 sel
    ) external view returns (string memory errorSignature);

    /**
     * @dev Calculates the 4-byte function or error selector from its signature string.
     * @param fsigStr The full signature string (e.g., "transfer(address,uint256)").
     * @return fsig The calculated 4-byte selector.
     */
    function stringToFsig(
        string calldata fsigStr
    ) external pure returns (bytes4 fsig);
}
