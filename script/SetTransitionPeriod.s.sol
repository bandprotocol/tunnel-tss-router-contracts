// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {TssVerifier} from "../src/TssVerifier.sol";

contract Deployer is Script {
    function run() external {
        address tssVerifierAddr = vm.envAddress("TSS_VERIFIER");
        uint64 transitionPeriod = uint64(vm.envUint("TRANSITION_PERIOD"));

        vm.startBroadcast();

        TssVerifier tssVerifier = TssVerifier(tssVerifierAddr);
        tssVerifier.setTransitionPeriod(transitionPeriod);

        vm.stopBroadcast();

        console.log("tssVerifier address:", tssVerifierAddr);
        console.log("transition period:", tssVerifier.transitionPeriod());
    }
}
