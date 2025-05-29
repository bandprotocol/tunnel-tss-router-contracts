// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {IPacketConsumer} from "../src/interfaces/IPacketConsumer.sol";
import {PacketConsumer} from "../src/PacketConsumer.sol";
import {PacketConsumerProxy} from "../src/PacketConsumerProxy.sol";


contract DeployScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address packetConsumerAddr = vm.envAddress("PACKET_CONSUMER");

        vm.startBroadcast(privKey);

        PacketConsumerProxy packetConsumerProxy = new PacketConsumerProxy(IPacketConsumer(packetConsumerAddr), msg.sender);

        vm.stopBroadcast();

        console.log("PacketConsumerProxy deployed at:", address(packetConsumerProxy));
    }
}
