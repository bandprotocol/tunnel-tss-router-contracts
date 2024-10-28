// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/TssVerifier.sol";
import "./helper/TssSignerHelper.sol";

contract TssVerifierTest is Test, TssSignerHelper {
    bytes32 constant _HASH_ORIGINATOR_REPLACEMENT =
        0xB1E192CBEADD6C77C810644A56E1DD40CEF65DDF0CB9B67DD42CDF538D755DE2;

    // abi.keccak("bandtss")[:4] | abi.keccak("transition")[:4].
    bytes8 constant _UPDATE_KEY_PREFIX = 0x135e4b63acc0e671;
    uint256 constant _privateKey =
        uint256(keccak256(abi.encodePacked("TEST_PRIVATE_KEY")));
    TssVerifier public verifier;

    function setUp() public {
        (uint8 parity, uint256 px) = getPubkey(_privateKey);
        verifier = new TssVerifier(address(this));
        verifier.addPubKeyByOwner(parity - 25, CURRENT_PUBKEY_TIMESTAMP, px);
    }

    function cmpNewPubKey(
        uint256 expectTimestamp,
        uint8 expectParity,
        uint256 expectPx
    ) private view returns(bool) {
        return verifier.getPublicKey(expectParity, uint64(expectTimestamp)) == expectPx;
    }

    function testVerify() public {
        // -------------------------------------------------------------------------------- initial
        
        uint64 signingID = uint64(0);
        bytes32 hashOriginator = 0x00;
        uint64 timestamp = CURRENT_PUBKEY_TIMESTAMP;

        vm.warp(timestamp);

        // generate data and message to be signed.
        bytes memory data = abi.encodePacked("any message to be sign ------------  (1)");
        bytes memory message = this.getSigningMessage(
            hashOriginator,
            timestamp,
            signingID,
            data
        );
        bytes32 messageHash = keccak256(message);

        (uint8 parity, uint256 px) = getPubkey(_privateKey);
        (address randomAddr, uint256 s) = sign(
            parity,
            px,
            getRandomNonce(_privateKey),
            keccak256(abi.encode(_HASHED_CHAIN_ID, messageHash)),
            _privateKey
        );

        // verify signature
        uint256 gasDiff = gasleft();
        bool result = verifier.verify(parity, timestamp, randomAddr, s, messageHash);
        gasDiff = gasDiff - gasleft();
        assertEq(result, true);

        console.log("initial verify gas = ", gasDiff);

        // -------------------------------------------------------------------------------- next

        signingID++;

        vm.warp(timestamp + 1);

        // generate data and message to be signed.
        data = abi.encodePacked("any message to be sign ------------  (2)");
        message = this.getSigningMessage(
            hashOriginator,
            timestamp,
            signingID,
            data
        );
        messageHash = keccak256(message);

        (parity, px) = getPubkey(_privateKey);
        (randomAddr, s) = sign(
            parity,
            px,
            getRandomNonce(_privateKey + 1),
            keccak256(abi.encode(_HASHED_CHAIN_ID, messageHash)),
            _privateKey
        );

        // verify signature
        gasDiff = gasleft();
        result = verifier.verify(parity, timestamp, randomAddr, s, messageHash);
        gasDiff = gasDiff - gasleft();
        assertEq(result, true);

        console.log("next verify gas = ", gasDiff);
    }

    function testAddPubKeyWithProof() public {
        // -------------------------------------------------------------------------------- initial

        uint64 signingID = uint64(0);
        uint64 timestamp = CURRENT_PUBKEY_TIMESTAMP;

        // the current public key
        (uint8 parity, uint256 px) = getPubkey(_privateKey + 0);
        // prepare data for add new public key
        (uint8 newParity, uint256 newPx) = getPubkey(_privateKey + 1);

        vm.warp(timestamp);

        // generate new replacement signing message
        bytes memory data = abi.encodePacked(
            _UPDATE_KEY_PREFIX,
            newParity - 25,
            timestamp + 1,
            newPx
        );
        bytes memory message = this.getSigningMessage(
            _HASH_ORIGINATOR_REPLACEMENT,
            signingID,
            timestamp,
            data
        );
        bytes32 messageHash = keccak256(abi.encode(_HASHED_CHAIN_ID, keccak256(message)));

        // sign a message
        (address randomAddr, uint256 s) = sign(
            parity,
            px,
            getRandomNonce(_privateKey),
            messageHash,
            _privateKey + 0
        );

        // add new public key
        uint256 gasDiff = gasleft();
        verifier.addPubKeyWithProof(parity, timestamp, randomAddr, s, message);
        gasDiff = gasDiff - gasleft();

        // compare result and replace existing private key.
        assert(cmpNewPubKey(timestamp + 1, newParity, newPx));

        console.log("initial update pubkey gas = ", gasDiff);

        // -------------------------------------------------------------------------------- next

        signingID++;
        timestamp++;

        // the current public key
        (parity, px) = getPubkey(_privateKey + 1);
        // prepare data for add new public key
        (newParity, newPx) = getPubkey(_privateKey + 2);

        vm.warp(timestamp);

        // generate new replacement signing message
        data = abi.encodePacked(
            _UPDATE_KEY_PREFIX,
            newParity - 25,
            timestamp + 1,
            newPx
        );
        message = this.getSigningMessage(
            _HASH_ORIGINATOR_REPLACEMENT,
            signingID,
            timestamp,
            data
        );
        messageHash = keccak256(abi.encode(_HASHED_CHAIN_ID, keccak256(message)));

        // sign a message
        (randomAddr, s) = sign(
            parity,
            px,
            getRandomNonce(_privateKey + 1),
            messageHash,
            _privateKey + 1
        );

        // add new public key
        gasDiff = gasleft();
        verifier.addPubKeyWithProof(parity, timestamp, randomAddr, s, message);
        gasDiff = gasDiff - gasleft();

        // compare result and replace existing private key.
        assert(cmpNewPubKey(timestamp + 1, newParity, newPx));

        console.log("next update pubkey gas = ", gasDiff);
    }
}
