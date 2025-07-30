// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

// The contract to be tested
import "../../src/router/ErrorHandler.sol";

/// @dev Testable wrapper to expose the internal call function
contract TestableErrorHandler is ErrorHandler, Ownable2StepUpgradeable {
    function initialize(address owner_) external initializer {
        __Ownable2Step_init();
        _transferOwnership(owner_);
    }

    function call(
        address target,
        uint256 callbackGasLimit,
        bytes memory data
    ) external returns (bool, bytes memory) {
        return _callWithCustomErrorHandling(target, callbackGasLimit, data);
    }

    function registerError(
        address target,
        string calldata fsigStr
    ) external onlyOwner {
        _registerError(target, fsigStr);
    }

    function unregisterError(
        address target,
        string calldata fsigStr
    ) external onlyOwner {
        _unregisterError(target, fsigStr);
    }
}
