// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface ITssVerifier {
    // ========================================
    // Events
    // ========================================

    /**
     * @dev Emitted when the group public key is updated.
     *
     * @param index The index of the public key in the group.
     * @param timestamp The timestamp of the update.
     * @param parity The parity value of the public key.
     * @param px The x-coordinate value of the public key.
     * @param isByAdmin True if the public key is updated by the admin, false otherwise.
     */
    event UpdateGroupPubKey(
        uint256 index,
        uint256 timestamp,
        uint8 parity,
        uint256 px,
        bool isByAdmin
    );

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Revert the transaction if the message and its signature doesn't match.
     */
    error InvalidSignature();

    /**
     * @notice Revert the transaction if the contract fails to processes the signature.
     */
    error FailProcessingSignature();

    /**
     * @notice Revert the transaction if there is no valid public key.
     */
    error PublicKeyNotFound(uint256 timestamp);

    // ========================================
    // Functions
    // ========================================

    /**
     * @dev verify the signature of the message against the given signature.
     *
     * @param message is the message to be verified.
     * @param randomAddr is the random address that is generated during the processing tss signature.
     * @param signature is the tss signature.
     * @return true if the signature is valid, false otherwise.
     */
    function verify(
        bytes calldata message,
        address randomAddr,
        uint256 signature
    ) external view returns (bool);

    /**
     * @dev Add the new public key with proof from the current group.
     * @param message is the message being used for updating public key.
     * @param randomAddr is the address form of the commitment R.
     * @param s represents the Schnorr signature.
     */
    function addPubKeyWithProof(
        bytes calldata message,
        address randomAddr,
        uint256 s
    ) external;

    /**
     * @dev Add the new public key by the owner.
     * @param parity is the parity value of the new public key
     * @param px is the x-coordinate value of the new public key
     */
    function addPubKeyByOwner(uint8 parity, uint256 px) external;
}
