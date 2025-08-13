// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {Script} from "forge-std/Script.sol";

import {Vault} from "../src/Vault.sol";
import {PacketConsumer} from "../src/PacketConsumer.sol";
import {BaseTunnelRouter} from "../src/router/BaseTunnelRouter.sol";

contract Executor is Script {
    function run() external {
        uint256 depositAmount = vm.envOr("DEPOSIT_AMOUNT", uint256(0));
        uint64 tunnelId = uint64(vm.envUint("TUNNEL_ID"));
        address packetConsumerAddr = vm.envAddress("PACKET_CONSUMER");
        uint64 sequence = uint64(vm.envOr("SEQUENCE", uint256(0)));

        require(tunnelId != 0, "tunnel id is not set");

        vm.startBroadcast();

        PacketConsumer packetConsumer = PacketConsumer(packetConsumerAddr);

        address tunnelRouterAddr = packetConsumer.tunnelRouter();
        BaseTunnelRouter tunnelRouter = BaseTunnelRouter(tunnelRouterAddr);
        BaseTunnelRouter.TunnelInfo memory tunnelInfo = tunnelRouter.tunnelInfo(
            tunnelId,
            packetConsumerAddr
        );

        // If the tunnel is active, deactivate it first
        if (tunnelInfo.isActive) {
            packetConsumer.deactivate(tunnelId);
        }

        packetConsumer.activate{value: depositAmount}(tunnelId, sequence);

        vm.stopBroadcast();

        Vault vault = Vault(payable(address(tunnelRouter.vault())));
        uint256 balance = vault.balance(tunnelId, packetConsumerAddr);
        tunnelInfo = tunnelRouter.tunnelInfo(tunnelId, packetConsumerAddr);

        console.log("consumer address:", packetConsumerAddr);
        console.log("tunnel id:", tunnelId);
        console.log("tunnel sequence:", tunnelInfo.latestSequence);
        console.log("tunnel isActive:", tunnelInfo.isActive);
        console.log(
            "current balance of the packet consumer in vault:",
            balance
        );
    }
}
