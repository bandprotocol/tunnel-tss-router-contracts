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
        address implTunnelRouterAddr = Upgrades.deployImplementation("PriorityFeeTunnelRouter.sol", opts);

        vm.stopBroadcast();

        console.log(
            "PriorityFeeTunnelRouter Implementation deployed at:",
            implTunnelRouterAddr
        );
    }
}
