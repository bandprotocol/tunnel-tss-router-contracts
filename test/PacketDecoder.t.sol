// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/PacketDecoder.sol";
import "./helper/Constants.sol";

contract PacketDecoderTest is Test, PacketDecoder, Constants {
    function decodeTssMessage(
        bytes calldata message
    ) public pure returns (TssMessage memory) {
        return _decodeTssMessage(message);
    }

    function testDecodeTssMessage() public view {
        TssMessage memory tssMessage = this.decodeTssMessage(TSS_RAW_MESSAGE);
        Packet memory packet = tssMessage.packet;

        TssMessage memory expectedMsg = this.DECODED_TSS_MESSAGE();
        Packet memory expectedPacket = expectedMsg.packet;

        // check tss Message.
        assertEq(uint8(tssMessage.encoderType), uint8(EncoderType.FixedPoint));
        assertEq(tssMessage.hashChainID, expectedMsg.hashChainID);
        assertEq(tssMessage.hashOriginator, expectedMsg.hashOriginator);
        assertEq(
            tssMessage.sourceBlockTimestmap,
            expectedMsg.sourceBlockTimestmap
        );
        assertEq(tssMessage.signingID, expectedMsg.signingID);

        // check packet.
        assertEq(packet.tunnelID, expectedPacket.tunnelID);
        assertEq(packet.nonce, expectedPacket.nonce);
        assertEq(packet.signals[0].signal, expectedPacket.signals[0].signal);
        assertEq(packet.signals[0].price, expectedPacket.signals[0].price);
        assertEq(packet.timestmap, expectedPacket.timestmap);
    }
}
