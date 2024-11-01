// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/upgrades.sol";

import {IVault} from "../src/interfaces/IVault.sol";
import {ITssVerifier} from "../src/interfaces/ITssVerifier.sol";

import {GasPriceTunnelRouter} from "../src/GasPriceTunnelRouter.sol";
import {TssVerifier} from "../src/TssVerifier.sol";
import {Vault} from "../src/Vault.sol";

contract DeployScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        // Deploy the proxy vault contract
        address proxyVaultAddr = Upgrades.deployTransparentProxy(
            "Vault.sol",
            msg.sender,
            abi.encodeCall(Vault.initialize, (msg.sender, address(0x00)))
        );
        address implVaultAddr = Upgrades.getImplementationAddress(
            proxyVaultAddr
        );

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(msg.sender);

        // Deploy the proxy TunnelRouter contract
        address proxyTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "GasPriceTunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                GasPriceTunnelRouter.initialize,
                (
                    tssVerifier,
                    IVault(proxyVaultAddr),
                    0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0, // keccak256("eth")
                    msg.sender,
                    0,
                    0,
                    0
                )
            )
        );
        address implTunnelRouterAddr = Upgrades.getImplementationAddress(
            proxyTunnelRouterAddr
        );

        vm.stopBroadcast();

        console.log("Vault Proxy deployed at :", proxyVaultAddr);
        console.log("Vault Implementation deployed at :", implVaultAddr);
        console.log("TssVerifier deployed at :", address(tssVerifier));
        console.log(
            "GasPriceTunnelRouter Proxy deployed at :",
            proxyTunnelRouterAddr
        );
        console.log(
            "GasPriceTunnelRouter Implementation deployed at :",
            implTunnelRouterAddr
        );
    }
}
