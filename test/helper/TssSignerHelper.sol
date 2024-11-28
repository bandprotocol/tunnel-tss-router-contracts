// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/TssVerifier.sol";
import "./SECP256k1.sol";

contract TssSignerHelper is Test {
    // secp256k1 group order
    uint256 public constant ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /// @dev Gets the signing message that will be used in signing of the tss module.
    function getSigningMessage(bytes32 hashOriginator, uint64 signingID, uint64 timestamp, bytes calldata rawMessage)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(hashOriginator, timestamp, signingID, rawMessage);
    }

    /// @dev Generates new public key.
    function getPubkey(uint256 privateKey) public pure returns (uint8 parity, uint256 px) {
        uint256 py;
        (px, py) = SECP256k1.publicKey(privateKey);
        parity = 27;
        if (py & 1 == 1) {
            parity = 28;
        }
    }

    /// @dev Generates the challenge context that will be used in checking verifying signature.
    function challenge(uint8 _parity, address randomAddr, uint256 _px, bytes32 messageHash)
        public
        pure
        returns (uint256 c)
    {
        c = uint256(
            keccak256(
                abi.encodePacked(
                    bytes32(0x42414e442d5453532d736563703235366b312d7630006368616c6c656e676500),
                    randomAddr,
                    _parity,
                    _px,
                    messageHash
                )
            )
        );
    }

    /// @dev Generates a nonce for that private key; this is not an rng function.
    function getRandomNonce(uint256 privateKey) public pure returns (uint256 k) {
        k = uint256(keccak256(abi.encodePacked("salt", privateKey)));
    }

    /// @dev Generates schnorr signature on the given message.
    function sign(uint8 parity, uint256 px, uint256 randomNonce, bytes32 messageHash, uint256 privateKey)
        public
        pure
        returns (address randomAddr, uint256 s)
    {
        randomAddr = vm.addr(randomNonce);
        // c = h(address(R) || compressed pubkey || m)
        uint256 c = challenge(parity, randomAddr, px, messageHash);
        // cx = c*x
        uint256 cx = mulmod(c, privateKey, ORDER);
        // s = k + cx
        s = addmod(randomNonce, cx, ORDER);
    }
}
