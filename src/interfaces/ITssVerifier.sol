// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface ITssVerifier {
    // ========================================
    // Events
    // ========================================

    /**
     * @dev Emitted when the group public key is updated.
     * @param index The index of the public key in the group.
     * @param timestamp The timestamp of the update.
     * @param parity The parity value of the public key.
     * @param px The x-coordinate value of the public key.
     * @param isByAdmin True if the public key is updated by the admin, false otherwise.
     */
    event GroupPubKeyUpdated(
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
     * @notice Reverts if the message and its signature doesn't match.
     */
    error InvalidSignature();

    /**
     * @notice Reverts if the contract fails to processes the signature.
     */
    error ProcessingSignatureFailed();

    /**
     * @notice Reverts if there is no valid public key.
     *
     * @param timestamp The given timestamp of the message.
     */
    error PublicKeyNotFound(uint256 timestamp);

    // ========================================
    // Functions
    // ========================================

    /**
     * @dev Verifies the signature of the message against the given signature.
     *
     * @param message The message to be verified.
     * @param randomAddr The random address that is generated during the processing tss signature.
     * @param signature The tss signature.
     * @param timestamp The timestamp of the message.
     * @return true If the signature is valid, false otherwise.
     */
    function verify(
        bytes calldata message,
        address randomAddr,
        uint256 signature,
        uint256 timestamp
    ) external view returns (bool);

    /**
     * @dev Adds a new public key with proof from the current group.
     *
     * @param message The message being used for updating public key.
     * @param randomAddr The address form of the commitment R.
     * @param s The Schnorr signature.
     */
    function addPubKeyWithProof(
        bytes calldata message,
        address randomAddr,
        uint256 s
    ) external;

    /**
     * @dev Adds the new public key by the owner.
     *
     * @param parity The parity value of the new public key.
     * @param px The x-coordinate value of the new public key.
     */
    function addPubKeyByOwner(uint8 parity, uint256 px) external;
}
