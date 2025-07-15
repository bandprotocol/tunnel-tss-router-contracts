// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";

contract Deployer is Script {
    function run() external {
        address tunnelRouterAddr = vm.envAddress("TUNNEL_ROUTER");

        vm.startBroadcast();

        PacketConsumer packetConsumer = new PacketConsumer(
            tunnelRouterAddr,
            msg.sender
        );

        vm.stopBroadcast();

        console.log("PacketConsumer deployed at:", address(packetConsumer));
    }
}
