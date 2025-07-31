// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {PacketConsumer} from "../src/PacketConsumer.sol";
import {PacketConsumerProxy} from "../src/PacketConsumerProxy.sol";

contract Executor is Script {
    function run() external {
        address packetConsumerAddr = vm.envAddress("PACKET_CONSUMER");

        vm.startBroadcast();

        PacketConsumerProxy packetConsumerProxy = new PacketConsumerProxy(PacketConsumer(packetConsumerAddr), msg.sender);

        vm.stopBroadcast();

        console.log("PacketConsumerProxy deployed at: ", address(packetConsumerProxy));
    }
}
