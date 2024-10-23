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
    uint256 _privateKey =
        uint256(keccak256(abi.encodePacked("TEST_PRIVATE_KEY")));
    TssVerifier public verifier;

    function setUp() public {
        (uint8 parity, uint256 px) = getPubkey(_privateKey);
        verifier = new TssVerifier(_HASH_ORIGINATOR_REPLACEMENT, address(this));
        verifier.addPubKeyByOwner(parity - 25, px);
    }

    function cmpNewPubKey(
        uint256 expectTimestamp,
        uint8 expectParity,
        uint256 expectPx
    ) public view {
        uint256 nPubKey = verifier.publicKeyLength();
        (
            uint256 actualTimestamp,
            uint8 actualParity,
            uint256 actualPx
        ) = verifier.publicKeys(nPubKey - 1);
        assertEq(actualTimestamp, expectTimestamp);
        assertEq(actualParity, expectParity);
        assertEq(actualPx, expectPx);
    }

    struct TemporaryStore {
        uint256 nextPrivateKey;
        uint64 signingID;
        uint64 timestamp;
        bytes32 hashOriginator;
        uint8 parity;
        uint256 px;
        uint8 newParity;
        uint256 newPx;
        bytes32 messageHash;
        address rAddress;
        uint256 s;
        uint256 start;
        uint256 gasUsedVerifyAcc;
        uint256 gasUsedUpdateAcc;
    }

    function testVerify() public {
        uint256 privateKey = _privateKey;
        TemporaryStore memory tmp;

        for (uint256 i = 0; i < 100; i++) {
            tmp.signingID = uint64(i + 1);
            tmp.hashOriginator = 0x00;
            tmp.timestamp = uint64(block.timestamp + 1);
            vm.warp(tmp.timestamp);

            // generate data and message to be signed.
            bytes memory data = abi.encodePacked(i, "any message to be sign");
            bytes memory message = this.getSigningMessage(
                tmp.hashOriginator,
                tmp.signingID,
                tmp.timestamp,
                data
            );
            tmp.messageHash = keccak256(message);

            (tmp.parity, tmp.px) = getPubkey(privateKey);
            (tmp.rAddress, tmp.s) = schnorrSign(
                tmp.parity,
                tmp.px,
                getRandomNonce(privateKey),
                tmp.messageHash,
                privateKey
            );

            // verify signature
            tmp.start = gasleft();
            bool result = verifier.verify(message, tmp.rAddress, tmp.s);
            tmp.gasUsedVerifyAcc += tmp.start - gasleft();
            assertEq(result, true);

            // prepare data for add new public key
            tmp.nextPrivateKey = uint256(
                keccak256(abi.encodePacked(i, privateKey, "next privateKey"))
            );
            (tmp.newParity, tmp.newPx) = getPubkey(tmp.nextPrivateKey);

            // generate new replacement signing message
            data = abi.encodePacked(
                _UPDATE_KEY_PREFIX,
                tmp.newParity - 25,
                tmp.newPx
            );
            message = this.getSigningMessage(
                _HASH_ORIGINATOR_REPLACEMENT,
                tmp.signingID,
                tmp.timestamp,
                data
            );
            tmp.messageHash = keccak256(message);

            // sign a message
            (tmp.rAddress, tmp.s) = schnorrSign(
                tmp.parity,
                tmp.px,
                getRandomNonce(privateKey),
                tmp.messageHash,
                privateKey
            );

            // add new public key
            tmp.start = gasleft();
            verifier.addPubKeyWithProof(message, tmp.rAddress, tmp.s);
            tmp.gasUsedUpdateAcc += tmp.start - gasleft();

            // compare result and replace existing private key.
            cmpNewPubKey(tmp.timestamp, tmp.newParity, tmp.newPx);
            privateKey = tmp.nextPrivateKey;

            if (i == 0) {
                console.log("initial verify gas avg = ", tmp.gasUsedVerifyAcc);
                console.log(
                    "initial update pubkey gas avg = ",
                    tmp.gasUsedUpdateAcc
                );
            }
        }
        console.log("verify gas avg = ", tmp.gasUsedVerifyAcc / 100);
        console.log("update pubkey gas avg = ", tmp.gasUsedUpdateAcc / 100);
    }
}
