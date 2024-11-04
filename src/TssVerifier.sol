// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./interfaces/ITssVerifier.sol";

contract TssVerifier is Pausable, Ownable2Step, ITssVerifier {
    struct PublicKey {
        uint64 timestamp; // The timestamp that the public key is activated.
        uint8 parity; // The parity value of the public key.
        uint256 px; // The x-coordinate value of the public key.
    }

    // hashed chain ID of the TSS process;
    bytes32 constant _HASHED_CHAIN_ID =
        0x0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6;
    // The group order of secp256k1.
    uint256 constant _ORDER =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    // The prefix for the hashing process in bandchain.
    string constant _CONTEXT = "BAND-TSS-secp256k1-v0";
    // The prefix for the challenging hash message.
    string constant _CHALLENGE_PREFIX = "challenge";

    // The list of public keys that are used for the verification process.
    PublicKey[] public publicKeys;

    constructor(address initialAddr) Ownable(initialAddr) {}

    /**
     * @dev See {ITssVerifier-addPubKeyWithProof}.
     */
    function addPubKeyWithProof(
        bytes calldata message,
        address randomAddr,
        uint256 s
    ) external whenNotPaused {
        if (!verify(message, randomAddr, s, block.timestamp)) {
            revert InvalidSignature();
        }

        // Extract the public key from the message. The message is in the form of
        // hashedChainID (32 bytes) || hashedOrignator (32 bytes) || timestamp (uint64; 8-bytes)
        // || signingId (uint64; 8 bytes) || modulePrefix (8 bytes) || parity (1 byte) || px (32 bytes)
        uint8 parity = uint8(bytes1(message[88:89]));
        uint256 px = uint(bytes32(message[89:121]));

        _updatePublicKey(uint64(block.timestamp), parity, px);
    }

    /**
     * @dev See {ITssVerifier-addPubKeyByOwner}.
     */
    function addPubKeyByOwner(
        uint64 timestamp,
        uint8 parity,
        uint256 px
    ) external onlyOwner {
        _updatePublicKey(timestamp, parity, px);
    }

    /**
     * @dev See {ITssVerifier-verify}.
     */
    function verify(
        bytes calldata message,
        address randomAddr,
        uint256 signature,
        uint256 timestamp
    ) public view whenNotPaused returns (bool result) {
        if (randomAddr == address(0)) {
            return false;
        }

        if (bytes32(message[0:32]) != _HASHED_CHAIN_ID) {
            return false;
        }

        PublicKey memory pubKey = _getLatestPublicKeyBefore(timestamp);

        uint256 content = uint256(
            keccak256(
                abi.encodePacked(
                    _CONTEXT,
                    bytes1(0x00),
                    _CHALLENGE_PREFIX,
                    bytes1(0x00),
                    randomAddr,
                    pubKey.parity,
                    pubKey.px,
                    keccak256(message)
                )
            )
        );

        uint256 spx = _ORDER - mulmod(signature, pubKey.px, _ORDER);
        uint256 cpx = _ORDER - mulmod(content, pubKey.px, _ORDER);

        // Because the ecrecover precompile implementation verifies that the 'r' and's'
        // input positions must be non-zero
        // So in this case, there is no need to verify them('px' > 0 and 'cpx' > 0).
        if (spx == 0) {
            revert ProcessingSignatureFailed();
        }

        address addr = ecrecover(
            bytes32(spx),
            pubKey.parity,
            bytes32(pubKey.px),
            bytes32(cpx)
        );
        return randomAddr == addr;
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

    /// @dev push the public key to the list.
    function _updatePublicKey(
        uint64 timestamp,
        uint8 parity,
        uint256 px
    ) internal {
        // Note: Offset parity by 25 to match with the calculation in TSS module
        // In etheruem, the parity is typically 27 or 28.
        PublicKey memory pubKey = PublicKey({
            timestamp: timestamp,
            parity: parity + 25,
            px: px
        });
        publicKeys.push(pubKey);

        emit GroupPubKeyUpdated(publicKeys.length, timestamp, parity, px, true);
    }

    /// @dev Retrieves the most recent public key that is no later than the specified timestamp.
    function _getLatestPublicKeyBefore(
        uint256 timestamp
    ) internal view returns (PublicKey memory) {
        if (publicKeys.length == 0) {
            revert PublicKeyNotFound(timestamp);
        }

        for (int i = int256(publicKeys.length) - 1; i >= 0; i--) {
            if (publicKeys[uint256(i)].timestamp <= timestamp) {
                return publicKeys[uint256(i)];
            }
        }

        revert PublicKeyNotFound(timestamp);
    }
}
