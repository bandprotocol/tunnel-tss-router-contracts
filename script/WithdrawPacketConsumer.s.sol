// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";
import {BaseTunnelRouter} from "../src/router/BaseTunnelRouter.sol";
import {Vault} from "../src/Vault.sol";

contract Deployer is Script {
    function run() external {
        uint256 withdrawAmount = vm.envUint("WITHDRAW_AMOUNT");
        address packetConsumerAddr = vm.envAddress("PACKET_CONSUMER");

        vm.startBroadcast();

        PacketConsumer packetConsumer = PacketConsumer(packetConsumerAddr);
        packetConsumer.withdraw(withdrawAmount);

        vm.stopBroadcast();

        address tunnelRouterAddr = packetConsumer.tunnelRouter();
        BaseTunnelRouter tunnelRouter = BaseTunnelRouter(tunnelRouterAddr);

        Vault vault = Vault(payable(address(tunnelRouter.vault())));
        uint256 balance = vault.balance(
            packetConsumer.tunnelId(),
            packetConsumerAddr
        );

        console.log("consumer address:", packetConsumerAddr);
        console.log(
            "current balance of the packet consumer in vault:",
            balance
        );
    }
}
