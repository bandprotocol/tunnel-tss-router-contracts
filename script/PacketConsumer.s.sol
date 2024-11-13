// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";
import {PacketConsumerFactory} from "../src/PacketConsumerFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address packetConsumerFactory = vm.envAddress(
            "PACKET_CONSUMER_FACTORY"
        );
        uint64 tunnelId = uint64(vm.envUint("TUNNEL_ID"));

        vm.startBroadcast(privKey);

        PacketConsumerFactory factory = PacketConsumerFactory(
            packetConsumerFactory
        );

        // Deploy the PacketConsumer contract
        PacketConsumer packetConsumer = factory.createPacketConsumer(
            tunnelId,
            "salt"
        );

        vm.stopBroadcast();

        console.log("PacketConsumer deployed at:", address(packetConsumer));
    }
}
