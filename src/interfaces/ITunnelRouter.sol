// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface ITunnelRouter {
    /// @dev relay a message to the target contract.
    function relay(
        bytes calldata message,
        address targetAddr,
        address rAddr,
        uint signature
    ) external;

    /// @dev reactivate the caller contract with the latest nonce.
    function reactivate(uint64 latestNonce) external payable;

    /// @dev deactivate the caller contract.
    function deactivate() external;
}
