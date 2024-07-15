// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBandTssVerifier {
    function verifySignature(
        uint64 signingID,
        uint64 timestamp,
        bytes32 hashOriginator,
        address rAddress,
        uint256 s,
        bytes calldata data
    ) external view returns (bool);

    function getMessageHash(
        uint64 signingID,
        uint64 timestamp,
        bytes32 hashOriginator,
        bytes memory data
    ) external pure returns (bytes32);
}
