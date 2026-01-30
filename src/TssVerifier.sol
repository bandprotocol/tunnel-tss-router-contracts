// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./interfaces/ITssVerifier.sol";

contract TssVerifier is Pausable, Ownable2Step, ITssVerifier {
    // The group order of secp256k1.
    uint256 constant _ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    // The grace period for the public key.
    uint64 public transitionPeriod;
    // The originator hash of the transition message
    bytes32 public transitionOriginatorHash;
    // The prefix for the hashing process in bandchain.
    string constant _CONTEXT = "BAND-TSS-secp256k1-v0";
    // The prefix for the challenging hash message.
    string constant _CHALLENGE_PREFIX = "challenge";

    // The list of public keys that are used for the verification process.
    PublicKey[] public publicKeys;

    constructor(uint64 transitionPeriod_, bytes32 transitionOriginatorHash_, address initialAddr)
        Ownable(initialAddr)
    {
        _setTransitionPeriod(transitionPeriod_);
        _setTransitionOriginatorHash(transitionOriginatorHash_);
    }

    /**
     * @dev See {ITssVerifier-setTransitionPeriod}.
     */
    function setTransitionPeriod(uint64 transitionPeriod_) external onlyOwner {
        _setTransitionPeriod(transitionPeriod_);
    }

    /**
     * @dev See {ITssVerifier-setTransitionOriginatorHash}.
     */
    function setTransitionOriginatorHash(bytes32 transitionOriginatorHash_) external onlyOwner {
        _setTransitionOriginatorHash(transitionOriginatorHash_);
    }

    /**
     * @dev See {ITssVerifier-addPubKeyWithProof}.
     */
    function addPubKeyWithProof(bytes calldata message, address randomAddr, uint256 s) external whenNotPaused {
        if (bytes32(message[0:32]) != transitionOriginatorHash) {
            revert InvalidTransitionOriginatorHash();
        }

        if (!verify(keccak256(message), randomAddr, s)) {
            revert InvalidSignature();
        }

        // Extract the public key from the message. The message is in the form of
        // hashedOriginator (32 bytes) || timestamp (uint64; 8-bytes) || signingId (uint64; 8 bytes)
        // || modulePrefix (8 bytes) || parity (1 byte) || px (32 bytes) || timestamp (8 bytes)
        uint8 parity = uint8(bytes1(message[56:57]));
        uint256 px = uint256(bytes32(message[57:89]));
        uint64 timestamp = uint64(bytes8(message[89:97]));

        _updatePublicKey(timestamp, parity, px);
    }

    /**
     * @dev See {ITssVerifier-addPubKeyByOwner}.
     */
    function addPubKeyByOwner(uint64 timestamp, uint8 parity, uint256 px) external onlyOwner {
        _updatePublicKey(timestamp, parity, px);
    }

    /**
     * @dev See {ITssVerifier-verify}.
     */
    function verify(bytes32 hashedMessage, address randomAddr, uint256 signature)
        public
        view
        whenNotPaused
        returns (bool result)
    {
        if (randomAddr == address(0)) {
            return false;
        }

        // Get the public key that is valid at the given timestamp.
        uint256 pubKeyIdx = _getPubKeyIndexByTimestamp(uint64(block.timestamp));

        // If the active time of the public key is in the transition period, then
        // we need to check the previous public key as it may be the signature from
        // the previous group.
        PublicKey memory publicKey = publicKeys[pubKeyIdx];
        if (
            pubKeyIdx > 0 && publicKey.activeTime + transitionPeriod >= block.timestamp
                && _verifyWithPublicKey(hashedMessage, randomAddr, signature, publicKeys[pubKeyIdx - 1])
        ) {
            return true;
        }

        return _verifyWithPublicKey(hashedMessage, randomAddr, signature, publicKey);
    }

    /// @dev Pauses the contract to prevent any further updates.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpauses the contract to prevent any further updates.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev Returns the number of public keys.
    function publicKeysLength() public view returns (uint256 length) {
        length = publicKeys.length;
    }

    /// @dev Returns true if the signature is valid against the given public key.
    function _verifyWithPublicKey(
        bytes32 hashedMessage,
        address randomAddr,
        uint256 signature,
        PublicKey memory publicKey
    ) internal pure returns (bool) {
        uint256 content = uint256(
            keccak256(
                abi.encodePacked(
                    _CONTEXT,
                    bytes1(0x00),
                    _CHALLENGE_PREFIX,
                    bytes1(0x00),
                    randomAddr,
                    publicKey.parity,
                    publicKey.px,
                    hashedMessage
                )
            )
        );

        uint256 spx = _ORDER - mulmod(signature, publicKey.px, _ORDER);
        uint256 cpx = _ORDER - mulmod(content, publicKey.px, _ORDER);

        // Because the ecrecover precompile implementation verifies that the 'r' and's'
        // input positions must be non-zero
        // So in this case, there is no need to verify them('px' > 0 and 'cpx' > 0).
        if (spx == 0) {
            revert ProcessingSignatureFailed();
        }

        address addr = ecrecover(bytes32(spx), publicKey.parity, bytes32(publicKey.px), bytes32(cpx));
        return randomAddr == addr;
    }

    /// @dev Pushes the public key to the list.
    function _updatePublicKey(uint64 timestamp, uint8 parity, uint256 px) internal {
        // Note: Offset parity by 25 to match with the calculation in TSS module
        // In etheruem, the parity is typically 27 or 28.
        PublicKey memory pubKey = PublicKey({activeTime: timestamp, parity: parity + 25, px: px});
        publicKeys.push(pubKey);

        emit GroupPubKeyUpdated(publicKeys.length, timestamp, parity, px, true);
    }

    ///@dev Gets the public key index that is valid at th given timestamp.
    function _getPubKeyIndexByTimestamp(uint64 timestamp) internal view returns (uint256) {
        for (uint256 i = publicKeys.length; i > 0; i--) {
            if (publicKeys[i - 1].activeTime <= timestamp) {
                return i - 1;
            }
        }

        revert PublicKeyNotFound(timestamp);
    }

    /// @dev Sets the transition period.
    function _setTransitionPeriod(uint64 transitionPeriod_) internal {
        transitionPeriod = transitionPeriod_;
        emit TransitionPeriodUpdated(transitionPeriod_);
    }

    /// @dev Sets the transition originator hash.
    function _setTransitionOriginatorHash(bytes32 transitionOriginatorHash_) internal {
        transitionOriginatorHash = transitionOriginatorHash_;
        emit TransitionOriginatorHashUpdated(transitionOriginatorHash_);
    }
}
