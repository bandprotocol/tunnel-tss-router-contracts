// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/PacketConsumer.sol";
import "./helper/MockTunnelRouter.sol";
import "./helper/Constants.sol";

contract PacketConsumerTest is Test, Constants {
    PacketConsumer packetConsumer;
    MockTunnelRouter tunnelRouter;

    function setUp() public {
        tunnelRouter = new MockTunnelRouter();
        packetConsumer = new PacketConsumer(
            address(tunnelRouter),
            0xA37F90F0501F931F161F3C51421BED9A59819335D8D0F009D0E1357A863AC96B,
            address(this)
        );
    }

    function testProcess() public {
        tunnelRouter.relay(TSS_RAW_MESSAGE, packetConsumer);

        TssMessage memory tssMessage = DECODED_TSS_MESSAGE();
        Packet memory packet = tssMessage.packet;

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

        vm.expectRevert("PacketConsumer: Invalid hash originator");
        tunnelRouter.relay(message, packetConsumer);
    }

    function testCollectFee() public {
        address owner = vm.addr(1);
        vm.prank(owner);
        vm.deal(owner, 100 wei);
        (bool ok, ) = address(packetConsumer).call{value: 100 wei}("");
        assertEq(ok, true);
        assertEq(address(packetConsumer).balance, 100);
        vm.stopPrank();

        tunnelRouter.collectFee(packetConsumer, 100);
        assertEq(address(tunnelRouter).balance, 100);
        assertEq(address(packetConsumer).balance, 0);
    }

    function testCollectFeeInsufficientFund() public {
        address owner = vm.addr(1);
        vm.prank(owner);
        vm.deal(owner, 50 wei);
        (bool ok, ) = address(packetConsumer).call{value: 50 wei}("");
        assertEq(ok, true);
        assertEq(address(packetConsumer).balance, 50);
        vm.stopPrank();

        vm.expectRevert("PacketConsumer: insufficient balance");
        tunnelRouter.collectFee(packetConsumer, 100);
    }
}
