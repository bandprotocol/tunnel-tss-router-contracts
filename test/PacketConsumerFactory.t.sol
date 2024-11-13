// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/PacketConsumerFactory.sol";

contract PacketConsumerFactoryTest is Test {
    PacketConsumerFactory factory;

    function setUp() public {
        factory = new PacketConsumerFactory(
            keccak256("sourceChainID"),
            keccak256("targetChainID"),
            address(this)
        );
    }

    function checkDeployedAddress() public {
        address addr = factory.getPacketConsumerAddress("salt");
        PacketConsumer consumer = factory.createPacketConsumer(1, "salt");
        assertEq(addr, address(consumer));
        assertEq(consumer.tunnelId(), 1);
    }
}
