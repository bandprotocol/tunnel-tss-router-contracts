// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {Script} from "forge-std/Script.sol";

import {TssVerifier} from "../src/TssVerifier.sol";

contract Executor is Script {
    function run() external {
        uint64 transitionPeriod = uint64(vm.envUint("TRANSITION_PERIOD"));
        bytes32 transitionOriginatorHash = bytes32(
            vm.envUint("TRANSITION_ORIGINATOR_HASH")
        );

        require(transitionPeriod != 0, "TRANSITION_PERIOD is not set");
        require(
            transitionOriginatorHash != bytes32(0),
            "TRANSITION_ORIGINATOR_HASH is not set"
        );
        
        vm.startBroadcast();

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(
            transitionPeriod,
            transitionOriginatorHash,
            msg.sender
        );

        vm.stopBroadcast();

        console.log("TssVerifier deployed at:", address(tssVerifier));
    }
}
