// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/upgrades.sol";

import {IVault} from "../src/interfaces/IVault.sol";
import {ITssVerifier} from "../src/interfaces/ITssVerifier.sol";

import {GasPriceTunnelRouter} from "../src/router/GasPriceTunnelRouter.sol";
import {TssVerifier} from "../src/TssVerifier.sol";
import {Vault} from "../src/Vault.sol";

contract DeployScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        uint64 transitionPeriod = uint64(vm.envUint("TRANSITION_PERIOD"));

        vm.startBroadcast(privKey);

        // Deploy the proxy vault contract
        address proxyVaultAddr = Upgrades.deployTransparentProxy(
            "Vault.sol", msg.sender, abi.encodeCall(Vault.initialize, (msg.sender, address(0x00)))
        );
        address implVaultAddr = Upgrades.getImplementationAddress(proxyVaultAddr);

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(transitionPeriod, msg.sender);

        // Deploy the proxy TunnelRouter contract
        address proxyTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "GasPriceTunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                GasPriceTunnelRouter.initialize,
                (tssVerifier, IVault(proxyVaultAddr), msg.sender, 100000, 300000, 0.11 gwei)
            )
        );
        address implTunnelRouterAddr = Upgrades.getImplementationAddress(proxyTunnelRouterAddr);

        // Set the tunnel router address in the vault
        Vault(payable(proxyVaultAddr)).setTunnelRouter(proxyTunnelRouterAddr);

        vm.stopBroadcast();

        console.log("Vault Proxy deployed at :", proxyVaultAddr);
        console.log("Vault Implementation deployed at :", implVaultAddr);
        console.log("TssVerifier deployed at :", address(tssVerifier));
        console.log("GasPriceTunnelRouter Proxy deployed at :", proxyTunnelRouterAddr);
        console.log("GasPriceTunnelRouter Implementation deployed at :", implTunnelRouterAddr);
    }
}
