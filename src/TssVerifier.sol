// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/ITssVerifier.sol";

contract TssVerifier is Pausable, Ownable2Step, ITssVerifier {
    struct PublicKey {
        uint timestamp; // The timestamp that the public key is activated.
        uint8 parity; // The parity value of the public key.
        uint256 px; // The x-coordinate value of the public key.
    }

    // hashed chain ID of the TSS process;
    bytes32 constant _HASH_CHAIN_ID =
        0x0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6;
    // The group order of secp256k1.
    uint256 constant _ORDER =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    // The prefix for the key update message.
    bytes8 constant _UPDATE_KEY_PREFIX = 0x135e4b6353a9c808;
    // The prefix for the hashing process in bandchain.
    string constant _CONTEXT = "BAND-TSS-secp256k1-v0";
    // The prefix for the challenging hash message.
    string constant _CHALLENGE_PREFIX = "challenge";

    // the hashed originator of the replacement message.
    bytes32 public immutable hashOriginatorReplacement;
    // The list of public keys that are used for the verification process.
    PublicKey[] public publicKeys;

    event UpdateGroupPubKey(
        uint256 index,
        uint timestamp,
        uint8 parity,
        uint256 px,
        bool isByAdmin
    );

    constructor(bytes32 hashOriginatorReplacement_) {
        hashOriginatorReplacement = hashOriginatorReplacement_;
    }

    /// @dev Add the new public key with proof from the current group.
    /// @param message is the message being used for updating public key.
    /// @param rAddress is the address form of the commitment R.
    /// @param s represents the Schnorr signature.
    function addPubKeyWithProof(
        bytes calldata message,
        address rAddress,
        uint256 s
    ) external whenNotPaused {
        require(this.verify(message, rAddress, s), "TssVerifier: !verify");

        uint8 parity = uint8(bytes1(message[88:89]));
        uint px = uint(bytes32(message[89:121]));

        PublicKey memory pubKey = PublicKey({
            timestamp: block.timestamp,
            parity: parity + 25,
            px: px
        });
        publicKeys.push(pubKey);

        emit UpdateGroupPubKey(
            publicKeys.length,
            block.timestamp,
            parity,
            px,
            false
        );
    }

    /// @dev Add the new public key by the owner.
    /// @param parity is the parity value of the new public key
    /// @param px is the x-coordinate value of the new public key
    function addPubKeyByOwner(uint8 parity, uint256 px) external onlyOwner {
        PublicKey memory pubKey = PublicKey({
            timestamp: block.timestamp,
            parity: parity + 25,
            px: px
        });
        publicKeys.push(pubKey);

        emit UpdateGroupPubKey(
            publicKeys.length,
            block.timestamp,
            parity,
            px,
            true
        );
    }

    /// @dev Verify the signature of the message hash with the given public key.
    /// @param message is the message to be verified.
    /// @param rAddress is the address form of the commitment R.
    /// @param signature represents the Schnorr signature.
    /// @return result true if the signature is valid, false otherwise.
    function verify(
        bytes calldata message,
        address rAddress,
        uint256 signature
    ) public view whenNotPaused returns (bool result) {
        require(rAddress != address(0), "TssVerifier: !rAddress");
        require(
            bytes32(message[0:32]) == _HASH_CHAIN_ID,
            "TssVerifier: !_HASH_CHAIN_ID"
        );

        PublicKey memory pubKey = _getPublicKey(block.timestamp);

        uint256 content = uint256(
            keccak256(
                abi.encodePacked(
                    _CONTEXT,
                    bytes1(0x00),
                    _CHALLENGE_PREFIX,
                    bytes1(0x00),
                    rAddress,
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
        require(spx != 0, "TssVerifier: Invalid value of s*px");

        address addr = ecrecover(
            bytes32(spx),
            pubKey.parity,
            bytes32(pubKey.px),
            bytes32(cpx)
        );
        return rAddress == addr;
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

    /// @dev Retrieve the most recent public key that is no later than the specified timestamp.
    function _getPublicKey(
        uint timestamp
    ) internal view returns (PublicKey memory) {
        require(publicKeys.length > 0, "TssVerifier: !publicKeys");

        for (uint256 i = publicKeys.length - 1; i >= 0; i--) {
            if (publicKeys[i].timestamp <= timestamp) {
                return publicKeys[i];
            }
        }

        revert("TssVerifier: !timestamp");
    }
}
