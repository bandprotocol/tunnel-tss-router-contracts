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

    /**
     * @dev Add the new public key with proof from the current group.
     * @param message is the message being used for updating public key.
     * @param rAddress is the address form of the commitment R.
     * @param s represents the Schnorr signature.
     */
    function addPubKeyWithProof(
        bytes calldata message,
        address rAddress,
        uint256 s
    ) external;

    /**
     * @dev Add the new public key by the owner.
     * @param parity is the parity value of the new public key
     * @param px is the x-coordinate value of the new public key
     */
    function addPubKeyByOwner(uint8 parity, uint256 px) external;
}
