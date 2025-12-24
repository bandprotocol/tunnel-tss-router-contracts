// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades, UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {IVault} from "../src/interfaces/IVault.sol";
import {PriorityFeeTunnelRouter} from "../src/router/PriorityFeeTunnelRouter.sol";
import {TssVerifier} from "../src/TssVerifier.sol";

contract Executor is Script {
    function run() external {
        uint256 priorityFee = vm.envUint("PRIORITY_FEE");
        string memory sourceChainId = vm.envString("SOURCE_CHAIN_ID");
        string memory targetChainId = vm.envString("TARGET_CHAIN_ID");

        address implTunnelRouterAddr = vm.envAddress("TUNNEL_ROUTER_IMPL");
        address tssVerifierAddr = vm.envAddress("TSS_VERIFIER");
        TssVerifier tssVerifier = TssVerifier(tssVerifierAddr);
        address proxyVaultAddr = vm.envAddress("VAULT");

        require(
            keccak256(bytes(sourceChainId)) != keccak256(""),
            "SOURCE_CHAIN_ID is not set"
        );
        require(
            keccak256(bytes(targetChainId)) != keccak256(""),
            "TARGET_CHAIN_ID is not set"
        );

        vm.startBroadcast();

         // Deploy the proxy TunnelRouter contract
        address proxyTunnelRouterAddr = UnsafeUpgrades.deployTransparentProxy(
            implTunnelRouterAddr,
            msg.sender,
            abi.encodeCall(
                PriorityFeeTunnelRouter.initialize,
                (
                    tssVerifier,
                    IVault(proxyVaultAddr),
                    17369806436495577561272982365083344973322337688717046180703435,
                    4000,
                    300000,
                    priorityFee,
                    keccak256(bytes(sourceChainId)),
                    keccak256(bytes(targetChainId))
                )
            )
        );

        address adminTunnelRouterAddr = Upgrades.getAdminAddress(
            proxyTunnelRouterAddr
        );

        vm.stopBroadcast();

        console.log(
            "PriorityFeeTunnelRouter Proxy deployed at:",
            proxyTunnelRouterAddr
        );
        console.log(
            "PriorityFeeTunnelRouter Admin deployed at:",
            adminTunnelRouterAddr
        );
    }
}
