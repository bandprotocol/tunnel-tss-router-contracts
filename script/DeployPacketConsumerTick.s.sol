// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumerTick} from "../src/PacketConsumerTick.sol";

contract Executor is Script {
    function run() external {
        address tunnelRouterAddr = vm.envAddress("TUNNEL_ROUTER");

        vm.startBroadcast();

        PacketConsumerTick packetConsumer = new PacketConsumerTick(tunnelRouterAddr);

        vm.stopBroadcast();

        console.log("PacketConsumer deployed at:", address(packetConsumer));
    }
}
