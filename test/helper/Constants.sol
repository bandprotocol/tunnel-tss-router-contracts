// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../../src/libraries/PacketDecoder.sol";

contract Constants {
    uint8 CURRENT_GROUP_PARITY = 2;
    uint256 CURRENT_GROUP_PX =
        0xc0ebd57be3c91f2d1e4902eb8f7d86cffca9d8666261575c66c67f01ae4ae6bd;

    bytes constant TSS_RAW_MESSAGE =
        abi.encodePacked(
            hex"1685a5b64d5adf67aa720fd286ebbcce80b1c9555c75bce045a3c52c726c9108"
            hex"00000000672d7dd4",
            hex"0000000000000001",
            hex"d3813e0ccba0ad5a",
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"00000000000000000000000000000000000000000000000000000000000000c0",
            hex"0000000000000000000000000000000000000000000000000000000000000100",
            hex"0000000000000000000000000000000000000000000000000000000000000160",
            hex"00000000000000000000000000000000000000000000000000000000672d7dd4",
            hex"000000000000000000000000000000000000000000000000000000000000000b",
            hex"746573746e65742d65766d000000000000000000000000000000000000000000",
            hex"000000000000000000000000000000000000000000000000000000000000002a",
            hex"3078653030463166383561624442326146363736303735393534376434353064",
            hex"6136384345363642623100000000000000000000000000000000000000000000",
            hex"0000000000000000000000000000000000000000000000000000000000000002",
            hex"0000000000000000000000000000000000000000000043533a4254432d555344",
            hex"0000000000000000000000000000000000000000000000000000000000000000",
            hex"0000000000000000000000000000000000000000000043533a4554482d555344",
            hex"0000000000000000000000000000000000000000000000000000000000000000"
        );
    uint256 constant MESSAGE_SIGNATURE =
        0xdb1487a4227350bd9a0e0f9f9bd7e2a769414fbac733f68eff9e8a01352de63a;
    address constant SIGNATURE_NONCE_ADDR =
        0x876172f41ea36aa6820105D4a754409054A59953;
    address constant MOCK_SENDER = 
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    function DECODED_TSS_MESSAGE()
        public
        pure
        returns (PacketDecoder.TssMessage memory)
    {
        PacketDecoder.SignalPrice[]
            memory signalPriceInfos = new PacketDecoder.SignalPrice[](2);
        bytes memory signalIDBtc = abi.encodePacked(
            hex"00000000000000000000000000000000000000000000",
            "CS:BTC-USD"
        );
        signalPriceInfos[0] = PacketDecoder.SignalPrice(
            bytes32(signalIDBtc),
            0
        );

        bytes memory signalIDEth = abi.encodePacked(
            hex"00000000000000000000000000000000000000000000",
            "CS:ETH-USD"
        );
        signalPriceInfos[1] = PacketDecoder.SignalPrice(
            bytes32(signalIDEth),
            0
        );

        PacketDecoder.Packet memory packet = PacketDecoder.Packet(
            1,
            1,
            "testnet-evm",
            "0xe00F1f85abDB2aF6760759547d450da68CE66Bb1",
            signalPriceInfos,
            1731034580
        );

        PacketDecoder.TssMessage memory tssMessage = PacketDecoder.TssMessage(
            0x1685a5b64d5adf67aa720fd286ebbcce80b1c9555c75bce045a3c52c726c9108,
            1731034580,
            1,
            PacketDecoder.EncoderType.FixedPoint,
            packet
        );

        return tssMessage;
    }

    constructor() {}
}
