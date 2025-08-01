// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface ITssVerifier {
    // ========================================
    // Structs
    // ========================================

    /**
     * @notice Represents a group public key used for signature verification.
     * @param activeTime The Unix timestamp from which this public key is considered active.
     * @param parity The parity of the y-coordinate, used for public key recovery.
     * @param px The x-coordinate of the public key.
     */
    struct PublicKey {
        uint64 activeTime;
        uint8 parity;
        uint256 px;
    }

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
    event GroupPubKeyUpdated(uint256 index, uint256 timestamp, uint8 parity, uint256 px, bool isByAdmin);

    /**
     * @dev Emitted when the transition period is updated.
     * @param transitionPeriod The new duration of the transition period.
     */
    event TransitionPeriodUpdated(uint64 transitionPeriod);

    /**
     * @dev Emitted when the transition originator hash is updated.
     * @param transitionOriginatorHash The new transition originator hash.
     */
    event TransitionOriginatorHashUpdated(bytes32 transitionOriginatorHash);

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Reverts if the message and its signature doesn't match.
     */
    error InvalidSignature();

    /**
     * @notice Reverts if the transition originator hash doesn't match with the one in the message.
     */
    error InvalidTransitionOriginatorHash();

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
     * The contract is not allowed to verify the message with obsolete public key.
     *
     * @param hashedMessage The hashed message to be verified.
     * @param randomAddr The random address that is generated during the processing tss signature.
     * @param signature The tss signature.
     * @return true If the signature is valid, false otherwise.
     */
    function verify(bytes32 hashedMessage, address randomAddr, uint256 signature) external view returns (bool);

    /**
     * @dev Adds a new public key with proof from the current group.
     *
     * @param message The message being used for updating public key.
     * @param randomAddr The address form of the commitment R.
     * @param signature  The tss signature.
     */
    function addPubKeyWithProof(bytes calldata message, address randomAddr, uint256 signature) external;

    /**
     * @dev Adds the new public key by the owner.
     *
     * @param timestamp The timestamp of the new public key.
     * @param parity The parity value of the new public key.
     * @param px The x-coordinate value of the new public key.
     */
    function addPubKeyByOwner(uint64 timestamp, uint8 parity, uint256 px) external;

    /**
     * @dev Sets the transition period of the tss signature.
     * The transition period is the period in which the previous public key is still valid even
     * though the new public key is already added.
     *
     * @param transitionPeriod_ The new duration of the transition period.
     */
    function setTransitionPeriod(uint64 transitionPeriod_) external;

    /**
     * @dev Sets the transition originator hash.
     * The transition originator hash is the hash of the originator of the transition message.
     *
     * @param transitionOriginatorHash_ The new transition originator hash.
     */
    function setTransitionOriginatorHash(bytes32 transitionOriginatorHash_) external;
}
