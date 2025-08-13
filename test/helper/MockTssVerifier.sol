// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {ITssVerifier} from "../../src/interfaces/ITssVerifier.sol";

contract MockTssVerifier is ITssVerifier {
    function verify(bytes32, address, uint256) public pure returns (bool) {
        return true;
    }

    function addPubKeyWithProof(
        bytes calldata message,
        address randomAddr,
        uint256 signature
    ) external {}

    function addPubKeyByOwner(
        uint64 timestamp,
        uint8 parity,
        uint256 px
    ) external {}

    function setTransitionPeriod(uint64) external {}

    function setTransitionOriginatorHash(bytes32) external {}
}
