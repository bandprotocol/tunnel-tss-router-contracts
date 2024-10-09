// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface ITssVerifier {
    /**
     * @dev verify the signature of the message against the given signature.
     *
     * @param message is the message to be verified.
     * @param rAddr is the random address that is generated during the processing tss signature.
     * @param signature is the tss signature.
     * @return true if the signature is valid, false otherwise.
     */
    function verify(
        bytes calldata message,
        address rAddr,
        uint256 signature
    ) external view returns (bool);
}
