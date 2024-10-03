// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/PacketDecoder.sol";

contract PacketDecoderTest is Test, PacketDecoder {
    function decodeTssMessage(
        bytes calldata message
    ) public pure returns (TssMessage memory) {
        return _decodeTssMessage(message);
    }

    function testDecodeTssMessage() public view {
        bytes memory message = abi.encodePacked(
            hex"0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6",
            hex"A37F90F0501F931F161F3C51421BED9A59819335D8D0F009D0E1357A863AC96B",
            hex"0000000066FE6FED0000000000000013D3813E0CCBA0AD5A",
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000013",
            hex"0000000000000000000000000000000000000000000000000000000000000080",
            hex"0000000000000000000000000000000000000000000000000000000066FE6FED",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000455448",
            hex"0000000000000000000000000000000000000000000000000000000000000000"
        );

        SignalPrice[] memory signalPriceInfos = new SignalPrice[](1);
        bytes memory signalIDEth = abi.encodePacked(
            hex"0000000000000000000000000000000000000000000000000000000000",
            "ETH"
        );
        signalPriceInfos[0] = SignalPrice(bytes32(signalIDEth), 0);

        Packet memory packet = Packet(1, 19, signalPriceInfos, 1727950829);

        TssMessage memory expectedTssMessage = TssMessage(
            0x0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6,
            0xA37F90F0501F931F161F3C51421BED9A59819335D8D0F009D0E1357A863AC96B,
            1727950829,
            19,
            EncoderType.FixedPoint,
            packet
        );

        TssMessage memory tssMessage = this.decodeTssMessage(message);
        assertEq(uint8(tssMessage.encoderType), uint8(EncoderType.FixedPoint));
        assertEq(tssMessage.hashChainID, expectedTssMessage.hashChainID);
        assertEq(tssMessage.hashOriginator, expectedTssMessage.hashOriginator);
        assertEq(
            tssMessage.sourceBlockTimestmap,
            expectedTssMessage.sourceBlockTimestmap
        );
        assertEq(tssMessage.signingID, expectedTssMessage.signingID);
        assertEq(
            tssMessage.packet.tunnelID,
            expectedTssMessage.packet.tunnelID
        );
        assertEq(tssMessage.packet.nonce, expectedTssMessage.packet.nonce);
        assertEq(
            tssMessage.packet.signals[0].signal,
            expectedTssMessage.packet.signals[0].signal
        );
        assertEq(
            tssMessage.packet.signals[0].price,
            expectedTssMessage.packet.signals[0].price
        );
        assertEq(
            tssMessage.packet.timestmap,
            expectedTssMessage.packet.timestmap
        );
    }
}
