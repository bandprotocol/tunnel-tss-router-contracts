// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";

import {BaseTunnelRouter} from "../src/router/BaseTunnelRouter.sol";
import {TssVerifier} from "../src/TssVerifier.sol";

contract Deployer is Script {
    function run() external {
        address tunnelRouterAddr = vm.envOr("TUNNEL_ROUTER", address(0));
        address tssVerifierAddr = vm.envOr("TSS_VERIFIER", address(0));

        vm.startBroadcast();

        BaseTunnelRouter tunnelRouter;
        TssVerifier tssVerifier;

        if (tunnelRouterAddr != address(0)) {
            tunnelRouter = BaseTunnelRouter(tunnelRouterAddr);
            tunnelRouter.pause();
        }

        if (tssVerifierAddr != address(0)) {
            tssVerifier = TssVerifier(tssVerifierAddr);
            tssVerifier.pause();
        }

        vm.stopBroadcast();

        console.log("TunnelRouter paused status:", tunnelRouter.paused());
        console.log("TssVerifier paused status:", tssVerifier.paused());
    }
}
