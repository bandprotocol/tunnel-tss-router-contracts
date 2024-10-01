// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface ITssVerifier {
    /// @dev verify the signature of the message against the given random address and its signature.
    function verify(
        bytes calldata message,
        address rAddr,
        uint256 signature
    ) external view returns (bool);
}
