// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/upgrades.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";

contract DeployScript is Script {
    bytes32 constant _HASH_ORIGINATOR_REPLACEMENT =
        0xB1E192CBEADD6C77C810644A56E1DD40CEF65DDF0CB9B67DD42CDF538D755DE2;

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

        // Deploy the upgradeable TunnelRouter contract
        vm.stopBroadcast();

        console.log("PacketConsumer: ", address(packetConsumer));
    }
}
