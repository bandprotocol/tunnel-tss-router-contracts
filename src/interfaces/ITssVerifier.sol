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
    * @notice Thrown when there is no initial group of public keys set.
    */
    error NoInitialGroup();

    /**
    * @notice Thrown when the approver is not the previous group in the key update process.
    */
    error ApproverIsNotThePreviousGroup();

    /**
    * @notice Thrown when the new timestamp is not greater than the previous timestamp.
    */
    error NonIncreasingTimestamp();

    /**
    * @notice Thrown when an invalid key index is provided.
    */
    error InvalidKeyIndex();


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
     * @param parity is the y part of the current public key
     * @param timestamp is the creation timestamp of the current public key
     * @param randomAddr is the address form of the commitment R.
     * @param s is the integer part of the signature.
     * @param messageHash is the hash of the message to be verified.
     * @return true if the signature is valid, false otherwise.
     */
    function verify(
        uint8 parity,
        uint64 timestamp,
        address randomAddr,
        uint256 s,
        bytes32 messageHash
    ) external view returns (bool);

    /**
     * @dev Add the new public key with proof from the current group.
     * @param parity is the y part of the current public key
     * @param timestamp is the creation timestamp of the current public key
     * @param randomAddr is the address form of the commitment R.
     * @param s is the integer part of the signature.
     * @param message is the message being used for updating public key.
     */
    function addPubKeyWithProof(
        uint8 parity,
        uint64 timestamp,
        address randomAddr,
        uint256 s,
        bytes calldata message
    ) external;

    /**
     * @dev Add the new public key by the owner.
     * @param parity is the y part of the new public key
     * @param timestamp is the creation timestamp of the new public key
     * @param px is the x-coordinate value of the new public key
     */
    function addPubKeyByOwner(uint8 parity, uint64 timestamp, uint256 px) external;

    /**
     * @dev Inactive the groups based on the given indexes.
     * @param indexes is a list of indexes of keys that the owner wishes to make inactive.
     */
    function voidKeysByOwner(uint256[] calldata indexes) external;
}
