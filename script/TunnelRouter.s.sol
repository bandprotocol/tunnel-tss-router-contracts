// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/upgrades.sol";

import {ITssVerifier} from "../src/interfaces/ITssVerifier.sol";
import {IBandReserve} from "../src/interfaces/IBandReserve.sol";
import {BandReserve} from "../src/BandReserve.sol";
import {TssVerifier} from "../src/TssVerifier.sol";
import {TunnelRouter} from "../src/TunnelRouter.sol";

contract DeployScript is Script {
    bytes32 constant _HASH_ORIGINATOR_REPLACEMENT =
        0xB1E192CBEADD6C77C810644A56E1DD40CEF65DDF0CB9B67DD42CDF538D755DE2;

    function run() external {
        uint privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        // Deploy the upgradeable BandReserve contract
        address proxyBandReserveAddr = Upgrades.deployTransparentProxy(
            "BandReserve.sol",
            msg.sender,
            abi.encodeCall(BandReserve.initialize, (msg.sender))
        );
        address implBandReserveAddr = Upgrades.getImplementationAddress(
            proxyBandReserveAddr
        );

        // Deploy the TssVerifier contract
        TssVerifier tssVerifier = new TssVerifier(
            _HASH_ORIGINATOR_REPLACEMENT,
            msg.sender
        );

        // Deploy the upgradeable TunnelRouter contract
        address proxyTunnelRouterAddr = Upgrades.deployTransparentProxy(
            "TunnelRouter.sol",
            msg.sender,
            abi.encodeCall(
                TunnelRouter.initialize,
                (
                    ITssVerifier(tssVerifier),
                    IBandReserve(proxyBandReserveAddr),
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

        console.log("BandReserve Proxy: ", proxyBandReserveAddr);
        console.log("BandReserve Implementation: ", implBandReserveAddr);
        console.log("TssVerifier: ", address(tssVerifier));
        console.log("TunnelRouter Proxy: ", proxyTunnelRouterAddr);
        console.log("TunnelRouter Implementation: ", implTunnelRouterAddr);
    }
}
