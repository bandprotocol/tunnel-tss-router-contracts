// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";
import {BaseTunnelRouter} from "../src/router/BaseTunnelRouter.sol";

contract Executer is Script {
    function run() external {
        address packetConsumerAddr = vm.envAddress("PACKET_CONSUMER");

        vm.startBroadcast();

        PacketConsumer packetConsumer = PacketConsumer(packetConsumerAddr);
        packetConsumer.deactivate();

        vm.stopBroadcast();

        address tunnelRouterAddr = packetConsumer.tunnelRouter();
        BaseTunnelRouter tunnelRouter = BaseTunnelRouter(tunnelRouterAddr);
        BaseTunnelRouter.TunnelInfo memory tunnelInfo = tunnelRouter.tunnelInfo(
            packetConsumer.tunnelId(),
            packetConsumerAddr
        );

        console.log("tunnel id:", packetConsumer.tunnelId());
        console.log("tunnel isActive:", tunnelInfo.isActive);
    }
}
