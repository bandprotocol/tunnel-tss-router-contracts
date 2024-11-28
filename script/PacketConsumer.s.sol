// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {PacketConsumer} from "../src/PacketConsumer.sol";

contract DeployScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address tunnelRouterAddr = vm.envAddress("TUNNEL_ROUTER");
        string memory sourceChainId = vm.envString("SOURCE_CHAIN_ID");
        string memory destinationChainId = vm.envString("DESTINATION_CHAIN_ID");

        vm.startBroadcast(privKey);

        PacketConsumer packetConsumer = new PacketConsumer(
            tunnelRouterAddr, keccak256(bytes(sourceChainId)), keccak256(bytes(destinationChainId)), msg.sender
        );

        vm.stopBroadcast();

        console.log("PacketConsumer deployed at:", address(packetConsumer));
    }
}
