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
    bytes32 constant _HASH_ORIGINATOR_REPLACEMENT =
        0xB1E192CBEADD6C77C810644A56E1DD40CEF65DDF0CB9B67DD42CDF538D755DE2;

    function run() external {
        uint privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        // Deploy the proxy vault contract
        address proxyVaultAddr = Upgrades.deployTransparentProxy(
            "Vault.sol",
            msg.sender,
            abi.encodeCall(Vault.initialize, (msg.sender, 0, address(0x00)))
        );
        address implVaultddr = Upgrades.getImplementationAddress(
            proxyVaultAddr
        );

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(
            _HASH_ORIGINATOR_REPLACEMENT,
            msg.sender
        );

        // Deploy the proxy TunnelRouter contract
        address proxyTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "GasPriceTunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                GasPriceTunnelRouter.initialize,
                (
                    tssVerifier,
                    IVault(proxyVaultAddr),
                    "eth",
                    msg.sender,
                    0,
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

        console.log("Vault Proxy: ", proxyVaultAddr);
        console.log("Vault Implementation: ", implVaultddr);
        console.log("TssVerifier: ", address(tssVerifier));
        console.log("GasPriceTunnelRouter Proxy: ", proxyTunnelRouterAddr);
        console.log(
            "GasPriceTunnelRouter Implementation: ",
            implTunnelRouterAddr
        );
    }
}
