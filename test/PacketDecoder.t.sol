// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/libraries/PacketDecoder.sol";
import "./helper/Constants.sol";

contract PacketDecoderTest is Test, Constants {
    function decodeTssMessage(
        bytes calldata message
    ) public pure returns (PacketDecoder.TssMessage memory) {
        return PacketDecoder.decodeTssMessage(message);
    }

    function testDecodeTssMessage() public view {
        // set expected result.
        PacketDecoder.TssMessage memory expectedMsg = this
            .DECODED_TSS_MESSAGE();
        PacketDecoder.Packet memory expectedPacket = expectedMsg.packet;

        // get actual result.
        PacketDecoder.TssMessage memory tssMessage = this.decodeTssMessage(
            TSS_RAW_MESSAGE
        );
        PacketDecoder.Packet memory packet = tssMessage.packet;

        // check tss Message.
        assertEq(
            uint8(tssMessage.encoderType),
            uint8(PacketDecoder.EncoderType.FixedPoint)
        );
        assertEq(tssMessage.hashChainID, expectedMsg.hashChainID);
        assertEq(tssMessage.hashOriginator, expectedMsg.hashOriginator);
        assertEq(
            tssMessage.sourceBlockTimestmap,
            expectedMsg.sourceBlockTimestmap
        );
        assertEq(tssMessage.signingID, expectedMsg.signingID);

        // check packet.
        assertEq(packet.tunnelID, expectedPacket.tunnelID);
        assertEq(packet.sequence, expectedPacket.sequence);
        assertEq(packet.chainID, expectedPacket.chainID);
        assertEq(packet.targetAddr, expectedPacket.targetAddr);
        assertEq(packet.signals[0].signal, expectedPacket.signals[0].signal);
        assertEq(packet.signals[0].price, expectedPacket.signals[0].price);
        assertEq(packet.timestmap, expectedPacket.timestmap);
    }
}
