// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {TssVerifier} from "../src/TssVerifier.sol";

contract Deployer is Script {
    function run() external {
        address tssVerifierAddr = vm.envAddress("TSS_VERIFIER");
        uint64 times = uint64(vm.envUint("TIMESTAMP"));
        uint8 parity = uint8(vm.envUint("PARITY"));
        uint256 px = uint256(vm.envUint("PX"));

        vm.startBroadcast();

        TssVerifier tssVerifier = TssVerifier(tssVerifierAddr);
        tssVerifier.addPubKeyByOwner(times, parity, px);

        vm.stopBroadcast();

        uint256 publicKeysLength = TssVerifier(tssVerifierAddr)
            .publicKeysLength();

        console.log("tssVerifier address:", tssVerifierAddr);
        console.log("group public keys length:", publicKeysLength);

        for (uint256 i = 0; i < publicKeysLength; i++) {
            console.log("--------------------------------");

            (uint64 activeTime, uint8 parity, uint256 px) = tssVerifier
                .publicKeys(i);
            console.log("activeTime:", activeTime);
            console.log("parity:", parity);
            console.log("px:", px);
        }
    }
}
