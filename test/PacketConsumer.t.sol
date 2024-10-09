// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/libraries/PacketDecoder.sol";
import "../src/PacketConsumer.sol";
import "./helper/Constants.sol";
import "./helper/MockTunnelRouter.sol";

contract PacketConsumerTest is Test, Constants {
    PacketConsumer packetConsumer;
    MockTunnelRouter tunnelRouter;

    function setUp() public {
        tunnelRouter = new MockTunnelRouter();
        packetConsumer = new PacketConsumer(
            address(tunnelRouter),
            0x78512D24E95216DC140F557181A03631715A023424CBAD94601F3546CDFC3DE4,
            address(this)
        );
    }

    function testProcess() public {
        tunnelRouter.relay(TSS_RAW_MESSAGE, packetConsumer);

        PacketDecoder.TssMessage memory tssMessage = DECODED_TSS_MESSAGE();
        PacketDecoder.Packet memory packet = tssMessage.packet;

        // check prices mapping.
        (uint64 price, int64 timestamp) = packetConsumer.prices(
            packet.signals[0].signal
        );
        assertEq(price, packet.signals[0].price);
        assertEq(timestamp, packet.timestmap);
    }

    function testProcessInvalidHashOriginator() public {
        // fix originator hash.
        bytes memory message = TSS_RAW_MESSAGE;
        for (uint i = 32; i < 64; i++) {
            message[i] = 0x00;
        }
        vm.expectRevert("PacketConsumer: !hashOriginator");
        tunnelRouter.relay(message, packetConsumer);
    }
}
