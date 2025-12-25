// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/PacketConsumer.sol";
import "../src/PacketConsumerProxy.sol";

contract PacketConsumerProxyContract is Test {
    PacketConsumer packetConsumer;
    PacketConsumerProxy packetConsumerProxy;

    function setUp() public {
        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(address(this), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));

        packetConsumerProxy = new PacketConsumerProxy(packetConsumer, address(this));
    }

    function testSetPacketConsumer() public {
        bytes memory packetConsumerArgs = abi.encode(address(this), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));

        packetConsumerProxy.setPacketConsumer(packetConsumer);
    }

    function testSetPacketConsumerNotOwner() public {
        bytes memory packetConsumerArgs = abi.encode(address(this), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));

        // not owner caller
        vm.prank(address(uint160(0x2001)));
        vm.expectRevert();

        packetConsumerProxy.setPacketConsumer(packetConsumer);
    }
}
