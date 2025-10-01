// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";
import {BaseTunnelRouter} from "../src/router/BaseTunnelRouter.sol";

contract Executor is Script {
    function run() external {
        address packetConsumerAddr = vm.envAddress("PACKET_CONSUMER");
        uint64 tunnelId = uint64(vm.envUint("TUNNEL_ID"));

        require(tunnelId != 0, "tunnel id is not set");

        vm.startBroadcast();

        PacketConsumer packetConsumer = PacketConsumer(packetConsumerAddr);
        packetConsumer.deactivate(tunnelId);

        vm.stopBroadcast();

        address tunnelRouterAddr = packetConsumer.tunnelRouter();
        BaseTunnelRouter tunnelRouter = BaseTunnelRouter(tunnelRouterAddr);
        BaseTunnelRouter.TunnelInfo memory tunnelInfo = tunnelRouter.tunnelInfo(
            tunnelId,
            packetConsumerAddr
        );

        console.log("tunnel isActive:", tunnelInfo.isActive);
    }
}
