// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades, UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {Vault} from "../src/Vault.sol";

contract Executor is Script {
    function run() external {
        address implVaultAddr = vm.envAddress("VAULT_IMPL");

        vm.startBroadcast();

        // Deploy the proxy vault contract
        address proxyVaultAddr = UnsafeUpgrades.deployTransparentProxy(
            implVaultAddr,
            msg.sender,
            abi.encodeCall(Vault.initialize, (msg.sender, address(0x00)))
        );
        address adminVaultAddr = Upgrades.getAdminAddress(
            proxyVaultAddr
        );

        vm.stopBroadcast();

        console.log("Vault Proxy deployed at:", proxyVaultAddr);
        console.log("Vault Admin deployed at:", adminVaultAddr);
    }
}
