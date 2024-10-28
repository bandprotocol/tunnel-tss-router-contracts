// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/ITssVerifier.sol";

contract TssVerifier is Ownable2Step, ITssVerifier {
    // hashed chain ID of the TSS process;
    bytes32 constant _HASHED_CHAIN_ID =
        0x0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6;

    // In etheruem, the parity is typically 27 or 28, whereas in Cosmos it is 2 or 3.
    // We need to offset parity by 25 to match the calculation in the TSS module.
    uint8 constant _PARITY_OFFSET = 25;

    // The group order of secp256k1.
    uint256 constant _ORDER =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    // The prefix for the key update message. It comes from
    // keccak256("bandtss")[:4] | keccak256("transition")[:4].
    bytes8 constant _UPDATE_KEY_PREFIX = 0x135e4b63acc0e671;
    // The prefix for the hashing process in bandchain.
    string constant _CONTEXT = "BAND-TSS-secp256k1-v0";
    // The prefix for the challenging hash message.
    string constant _CHALLENGE_PREFIX = "challenge";
    // The keccak256(_CONTEXT | 0x00 | _CHALLENGE_PREFIX | 0x00)
    bytes32 public constant _COMBINED_PREFIX = 0x70dc541b29ea443932337070a89efa82095f5e6d1fd9845d0357be1f54ea4ec1;

    // A HashMap (parity|timestamp) => px in which the entire public key is parity, timestamp, and px
    mapping(uint256 => uint256) public publicKeys;

    // The list of public keys that are used for the verification process.
    uint256[] public keysTracking;

    event UpdateGroupPubKey(
        uint256 timestamp,
        uint8 parity,
        uint256 px,
        bool isByAdmin
    );

    constructor(address initialAddr) Ownable(initialAddr) {
        require(_COMBINED_PREFIX == keccak256(abi.encodePacked(_CONTEXT, bytes1(0x00), _CHALLENGE_PREFIX, bytes1(0x00))), "TssVerifier: !deploy");
    }

    /**
     * @dev See {ITssVerifier-addPubKeyWithProof}.
     */
    function addPubKeyWithProof(
        uint8 parity,
        uint64 timestamp,
        address randomAddr,
        uint256 s,
        bytes calldata message
    ) external {
        uint8 newParity = uint8(bytes1(message[56:57]));
        uint64 newTimestamp = uint64(bytes8(message[57:65]));
        uint256 newPX = uint256(bytes32(message[65:97]));

        if (keysTracking.length == 0) {
            revert NoInitialGroup();
        }
        if (keysTracking[keysTracking.length - 1] != (uint256(parity)<<64) + uint256(timestamp)) {
            revert ApproverIsNotThePreviousGroup();
        }
        if (newTimestamp <= timestamp) {
            revert NonIncreasingTimestamp();
        }
        if (!_verify(parity, timestamp, randomAddr, s, keccak256(message))) {
            revert InvalidSignature();
        }

        _addPubKey(false, newParity, newTimestamp, newPX);
    }

    /**
     * @dev See {ITssVerifier-addPubKeyByOwner}.
     */
    function addPubKeyByOwner(uint8 parity, uint64 timestamp, uint256 px) external onlyOwner {
        _addPubKey(true, parity, timestamp, px);
    }

    /**
     * @dev See {ITssVerifier-voidKeysByOwner}.
     */
    function voidKeysByOwner(uint256[] calldata indexes) external onlyOwner {
        for (uint256 i = 0; i < indexes.length; i++) {
            if (indexes[i] >= keysTracking.length) revert InvalidKeyIndex();
            publicKeys[keysTracking[indexes[i]]] = 0;
        }
    }

    /// @dev An internal function helps with the redundant code for adding a public key
    function _addPubKey(bool isByAdmin, uint8 parity, uint64 timestamp, uint256 px) internal {
        uint256 key = (uint256(parity + _PARITY_OFFSET)<<64) + uint256(timestamp);
        publicKeys[key] = px;
        keysTracking.push(key);

        emit UpdateGroupPubKey(
            timestamp,
            parity,
            px,
            isByAdmin
        );
    }

    /**
     * @dev See {ITssVerifier-verify}.
     */
    function verify(
        uint8 parity,
        uint64 timestamp,
        address randomAddr,
        uint256 s,
        bytes32 messageHash
    ) external view returns (bool result) {
        result = _verify(parity, timestamp, randomAddr, s, messageHash);
    }

    /// @dev An internal function that will be used by verify and addPubKeyWithProof
    function _verify(
        uint8 parity,
        uint64 timestamp,
        address randomAddr,
        uint256 s,
        bytes32 messageHash
    ) internal view returns (bool result) {
        // return false if the randomAddr is zero or incorrect hash chainID.
        if (randomAddr == address(0)) {
            return false;
        }

        uint256 px = getPublicKey(parity, timestamp);
        require(block.timestamp >= timestamp, "TssVerifier: !timestamp");

        uint256 content = uint256(
            keccak256(
                abi.encodePacked(
                    _COMBINED_PREFIX,
                    randomAddr,
                    parity,
                    px,
                    keccak256(abi.encode(_HASHED_CHAIN_ID, messageHash))
                )
            )
        );

        uint256 spx = _ORDER - mulmod(s, px, _ORDER);
        uint256 cpx = _ORDER - mulmod(content, px, _ORDER);

        // Because the ecrecover precompile implementation verifies that the 'r' and's'
        // input positions must be non-zero
        // So in this case, there is no need to verify them('px' > 0 and 'cpx' > 0).
        if (spx == 0) {
            revert FailProcessingSignature();
        }

        result = randomAddr == ecrecover(
            bytes32(spx),
            parity,
            bytes32(px),
            bytes32(cpx)
        );
    }

    /// @dev An external helper function that assists observing a px
    function getPublicKey(
        uint8 parity,
        uint64 timestamp
    ) public view returns (uint256 px) {
        px = publicKeys[(uint256(parity)<<64) + uint256(timestamp)];
        if (px == 0) {
            revert PublicKeyNotFound(timestamp);
        }
    }
}
