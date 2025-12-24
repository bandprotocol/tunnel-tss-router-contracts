// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

contract Executor is Script {
    function run() external {
        vm.startBroadcast();

        Options memory opts;
        address implVaultAddr = Upgrades.deployImplementation("Vault.sol", opts);

        vm.stopBroadcast();

        console.log("Vault Implementation deployed at:", implVaultAddr);
    }
}
