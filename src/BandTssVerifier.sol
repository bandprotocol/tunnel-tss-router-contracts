// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract BandTssVerifier is Pausable, Ownable2Step {
    // The hashed chain ID of the oracle result
    bytes32 constant HASH_CHAIN_ID =
        0x0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6;
    // The group order of secp256k1.
    uint256 constant ORDER =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    // The prefix for the key update message.
    bytes8 constant UPDATE_KEY_PREFIX = 0x135e4b6353a9c808;
    // The prefix for the hashing process in bandchain.
    string constant CONTEXT = "BAND-TSS-secp256k1-v0";
    // The prefix for the challenging hash message.
    string constant CHALLENGE_PREFIX = "challenge";

    // the hashed originator of the replacement message.
    bytes32 public immutable hashOriginatorReplacement;

    struct PublicKey {
        uint64 timestamp; // The timestamp that the public key is activated.
        uint8 parity; // The parity value of the public key.
        uint256 px; // The x-coordinate value of the public key.
    }

    struct VerifySignatureInput {
        uint64 signingID; // The ID of the signing request.
        uint64 timestamp; // The timestamp of the message that the signing request is created.
        bytes32 hashOriginator; // The hashed originator of the message.
        bytes data; // The raw data.
        address rAddress; // the group address of the commitment R.
        uint256 s; //represents the Schnorr signature.
    }

    // The list of public keys that are used for the verification process.
    PublicKey[] public publicKeys;

    event UpdateGroupPubKey(
        uint256 index,
        uint64 timestamp,
        uint8 parity,
        uint256 px
    );

    constructor(bytes32 hashOriginatorReplacement_) {
        hashOriginatorReplacement = hashOriginatorReplacement_;
    }

    /// @dev Add the new public key with proof from the current group.
    /// @param signingID is the signing ID of the replacement message.
    /// @param parity is the parity value of the new public key.
    /// @param px is the x-coordinate value of the new public key.
    /// @param rAddress is the address form of the commitment R.
    /// @param s represents the Schnorr signature.
    function addPubKeyWithProof(
        uint64 signingID,
        uint8 parity,
        uint256 px,
        address rAddress,
        uint256 s
    ) external whenNotPaused {
        uint nPubKey = publicKeys.length;
        uint64 timestamp = uint64(block.timestamp);
        require(nPubKey > 0, "BandTssBridge: No public key available.");

        PublicKey memory latestPubKey = publicKeys[nPubKey - 1];
        require(
            timestamp > latestPubKey.timestamp,
            "BandTssVerifier: new timestamp must be greater than the latest one."
        );

        bytes32 messageHash = getMessageHash(
            signingID,
            timestamp,
            hashOriginatorReplacement,
            abi.encodePacked(UPDATE_KEY_PREFIX, parity, px)
        );

        require(
            _verifySignature(rAddress, s, messageHash, latestPubKey),
            "BandTssVerifier: Public key update fails, the signature is invalid."
        );

        PublicKey memory pubKey = PublicKey({
            timestamp: timestamp,
            parity: parity + 25,
            px: px
        });
        publicKeys.push(pubKey);

        emit UpdateGroupPubKey(nPubKey, timestamp, parity, px);
    }

    /// @dev Add the new public key by the owner.
    /// @param parity is the parity value of the new public key
    /// @param px is the x-coordinate value of the new public key
    function addPubKeyByOwner(uint8 parity, uint256 px) external onlyOwner {
        uint nPubKey = publicKeys.length;
        uint64 timestamp = uint64(block.timestamp);
        if (nPubKey > 0) {
            PublicKey memory latestPubKey = publicKeys[nPubKey - 1];
            require(
                timestamp > latestPubKey.timestamp,
                "BandTssVerifier: new timestamp must be greater than the latest one."
            );
        }

        PublicKey memory pubKey = PublicKey({
            timestamp: timestamp,
            parity: parity + 25,
            px: px
        });
        publicKeys.push(pubKey);

        emit UpdateGroupPubKey(nPubKey, timestamp, parity, px);
    }

    /// @dev Verify the signature of the message hash with the given public key.
    /// @param signingID is the ID of the signing request.
    /// @param timestamp is the timestamp of the message that the signing request is created.
    /// @param hashOriginator is the hashed originator of the message.
    /// @param rAddress is the address form of the commitment R.
    /// @param s represents the Schnorr signature.
    /// @param data is the bytes raw data.
    /// @return result true if the signature is valid, false otherwise.
    function verifySignature(
        uint64 signingID,
        uint64 timestamp,
        bytes32 hashOriginator,
        address rAddress,
        uint256 s,
        bytes calldata data
    ) public view whenNotPaused returns (bool result) {
        bytes32 messageHash = getMessageHash(
            signingID,
            timestamp,
            hashOriginator,
            data
        );

        PublicKey memory pubKey = _getPublicKey(timestamp);
        return _verifySignature(rAddress, s, messageHash, pubKey);
    }

    /// @dev pause the contract to prevent any further updates.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev unpause the contract to prevent any further updates.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Returns the number of public keys.
    function publicKeyLength() public view returns (uint256 length) {
        length = publicKeys.length;
    }

    /// @dev Get the message hash of the given data.
    /// @param signingID is the ID of the signing request.
    /// @param timestamp is the timestamp of the message that the signing request is created.
    /// @param hashOriginator is the hashed originator of the message.
    /// @param data is the bytes raw data.
    function getMessageHash(
        uint64 signingID,
        uint64 timestamp,
        bytes32 hashOriginator,
        bytes memory data
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    HASH_CHAIN_ID,
                    hashOriginator,
                    timestamp,
                    signingID,
                    data
                )
            );
    }

    /// @dev Retrieve the most recent public key that is no later than the specified timestamp.
    function _getPublicKey(
        uint64 timestamp
    ) internal view returns (PublicKey memory) {
        uint nPubKey = publicKeys.length;
        require(nPubKey > 0, "BandTssBridge: No public key available.");

        for (uint256 i = publicKeys.length - 1; i >= 0; i--) {
            if (publicKeys[i].timestamp <= timestamp) {
                return publicKeys[i];
            }
        }

        revert(
            "BandTssVerifier: No public key available for the given timestamp."
        );
    }

    /// @dev Verify the signature of the message hash with the given public key.
    function _verifySignature(
        address rAddress,
        uint256 s,
        bytes32 messageHash,
        PublicKey memory pubKey
    ) internal pure returns (bool) {
        require(
            rAddress != address(0),
            "BandTssVerifier: Invalid address of R"
        );

        uint256 c = uint256(
            keccak256(
                abi.encodePacked(
                    CONTEXT,
                    bytes1(0x00),
                    CHALLENGE_PREFIX,
                    bytes1(0x00),
                    rAddress,
                    pubKey.parity,
                    pubKey.px,
                    messageHash
                )
            )
        );

        uint256 spx = ORDER - mulmod(s, pubKey.px, ORDER);
        uint256 cpx = ORDER - mulmod(c, pubKey.px, ORDER);

        // Because the ecrecover precompile implementation verifies that the 'r' and's'
        // input positions must be non-zero
        // So in this case, there is no need to verify them('px' > 0 and 'cpx' > 0).
        require(spx != 0, "BandTssVerifier: Invalid value of s*px");

        address addr = ecrecover(
            bytes32(spx),
            pubKey.parity,
            bytes32(pubKey.px),
            bytes32(cpx)
        );
        return rAddress == addr;
    }
}
