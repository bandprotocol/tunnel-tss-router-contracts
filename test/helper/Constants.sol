// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../../src/libraries/PacketDecoder.sol";

contract Constants {
    uint8 CURRENT_GROUP_PARITY = 2;
    uint256 CURRENT_GROUP_PX = 0xf885baa0c9853f95f41323a94de958ce15c178bc8e3efedb26e18ef1631b7650;

    bytes constant TSS_RAW_MESSAGE = abi.encodePacked(
        hex"1930634c04eaace73b84b572782f354be5c6c84233d24c0ede853409d89c3585",
        hex"00000000674c2ae0",
        hex"0000000000000001",
        hex"d3813e0ccba0ad5a",
        hex"0000000000000000000000000000000000000000000000000000000000000020",
        hex"0000000000000000000000000000000000000000000000000000000000000001",
        hex"0000000000000000000000000000000000000000000000000000000000000060",
        hex"00000000000000000000000000000000000000000000000000000000674c2ae0",
        hex"0000000000000000000000000000000000000000000000000000000000000002",
        hex"0000000000000000000000000000000000000000000043533a4254432d555344",
        hex"0000000000000000000000000000000000000000000000000000000000000000",
        hex"0000000000000000000000000000000000000000000043533a4554482d555344",
        hex"0000000000000000000000000000000000000000000000000000000000000000"
    );
    uint256 constant MESSAGE_SIGNATURE = 0x27f9063d0e40e9e3ab3e0d819383efa68c39472c0708bd37313cde954d795ea5;
    address constant SIGNATURE_NONCE_ADDR = 0x7BeBbc01C22D893dD71DC3D32c0D109f31556e4C;

    function DECODED_TSS_MESSAGE() public pure returns (PacketDecoder.TssMessage memory) {
        PacketDecoder.SignalPrice[] memory signalPriceInfos = new PacketDecoder.SignalPrice[](2);
        bytes memory signalIDBtc = abi.encodePacked(hex"00000000000000000000000000000000000000000000", "CS:BTC-USD");
        signalPriceInfos[0] = PacketDecoder.SignalPrice(bytes32(signalIDBtc), 0);

        bytes memory signalIDEth = abi.encodePacked(hex"00000000000000000000000000000000000000000000", "CS:ETH-USD");
        signalPriceInfos[1] = PacketDecoder.SignalPrice(bytes32(signalIDEth), 0);

        PacketDecoder.Packet memory packet = PacketDecoder.Packet(1, signalPriceInfos, 1733044960);

        PacketDecoder.TssMessage memory tssMessage = PacketDecoder.TssMessage(
            0x1930634c04eaace73b84b572782f354be5c6c84233d24c0ede853409d89c3585,
            1733044960,
            1,
            PacketDecoder.EncoderType.FixedPoint,
            packet
        );

        return tssMessage;
    }

    constructor() {}
}
