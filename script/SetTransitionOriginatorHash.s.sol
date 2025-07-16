// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {TssVerifier} from "../src/TssVerifier.sol";

contract Executor is Script {
    function run() external {
        address tssVerifierAddr = vm.envAddress("TSS_VERIFIER");
        bytes32 originatorHash = bytes32(vm.envUint("ORIGINATOR_HASH"));

        vm.startBroadcast();

        TssVerifier tssVerifier = TssVerifier(tssVerifierAddr);
        tssVerifier.setTransitionOriginatorHash(originatorHash);

        vm.stopBroadcast();

        console.log("tssVerifier address:", tssVerifierAddr);
        console.log("transition originator hash:");
        console.logBytes32(tssVerifier.transitionOriginatorHash());
    }
}
