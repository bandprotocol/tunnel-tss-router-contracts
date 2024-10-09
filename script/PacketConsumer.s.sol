// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";

contract DeployScript is Script {
    function run() external {
        uint privKey = vm.envUint("PRIVATE_KEY");
        address tunnelRouterAddr = vm.envAddress("TUNNEL_ROUTER");
        bytes32 hashOriginator = vm.envBytes32("HASH_ORIGINATOR");

        vm.startBroadcast(privKey);

        // Deploy the PacketConsumer contract
        PacketConsumer packetConsumer = new PacketConsumer(
            tunnelRouterAddr,
            hashOriginator,
            msg.sender
        );

        vm.stopBroadcast();

        console.log("PacketConsumer: ", address(packetConsumer));
    }
}
