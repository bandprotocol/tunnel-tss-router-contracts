// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../../src/interfaces/IDataConsumer.sol";

import "../../src/libraries/PacketDecoder.sol";

contract Constants {
    // secp256k1 group order
    uint256 public constant ORDER =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    // The hashed chain ID identified in the tss module.
    bytes32 public constant _HASHED_CHAIN_ID =
        0x0E1AC2C4A50A82AA49717691FC1AE2E5FA68EFF45BD8576B0F2BE7A0850FA7C6;

    // The mock creation timestamp of the current group
    uint64 public constant CURRENT_PUBKEY_TIMESTAMP = 1720000000;
    // The mock private key of the current group
    uint256 public constant CURRENT_GROUP_PRIVATE_KEY = 0x16dcaea64a5f1a8ae62fd706fc5c9b54cfeb8c0faab5b36de8c508942ac8ac92;

    // The mock (x,y) of the current group's public key
    uint8 public constant CURRENT_GROUP_PARITY = 27;
    uint256 public constant CURRENT_GROUP_PX = 0x5984ba36b84c566232e01451401b75fba750e04509c0736b8a05c855b31f0c7c;

    // Mockl TSS raw message
    bytes constant TSS_RAW_MESSAGE =
        abi.encodePacked(
            hex"78512D24E95216DC140F557181A03631715A023424CBAD94601F3546CDFC3DE4",
            hex"000000006705E8A00000000000000002D3813E0CCBA0AD5A",
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000002",
            hex"00000000000000000000000000000000000000000000000000000000000000C0",
            hex"0000000000000000000000000000000000000000000000000000000000000100",
            hex"0000000000000000000000000000000000000000000000000000000000000160",
            hex"000000000000000000000000000000000000000000000000000000006705E8A0",
            hex"0000000000000000000000000000000000000000000000000000000000000003",
            hex"6574680000000000000000000000000000000000000000000000000000000000",
            hex"000000000000000000000000000000000000000000000000000000000000002A",
            hex"307865303046316638356162444232614636373630373539353437643435306461363843453636426231",
            hex"00000000000000000000000000000000000000000000",
            hex"0000000000000000000000000000000000000000000000000000000000000002",
            hex"0000000000000000000000000063727970746F5F70726963652E627463757364",
            hex"0000000000000000000000000000000000000000000000000000000000000000",
            hex"0000000000000000000000000063727970746F5F70726963652E657468757364",
            hex"0000000000000000000000000000000000000000000000000000000000000000"
        );

    // The mock Schnorr signature of the current group on the TSS_RAW_MESSAGE
    uint256 public constant MESSAGE_SIGNATURE = 0x0d252f02a0898c328382dd475f2348a8643e1ff6ffde9f600df82a5f87a3205a;
    address public constant SIGNATURE_NONCE_ADDR = 0x38f2ceAfaAe3168FF9C1069E01Da8D3a787592D5;

    function DECODED_TSS_MESSAGE()
        public
        pure
        returns (PacketDecoder.TssMessage memory)
    {
        PacketDecoder.SignalPrice[]
            memory signalPriceInfos = new PacketDecoder.SignalPrice[](2);
        bytes memory signalIDBtc = abi.encodePacked(
            hex"00000000000000000000000000",
            "crypto_price.btcusd"
        );
        signalPriceInfos[0] = PacketDecoder.SignalPrice(
            bytes32(signalIDBtc),
            0
        );

        bytes memory signalIDEth = abi.encodePacked(
            hex"00000000000000000000000000",
            "crypto_price.ethusd"
        );
        signalPriceInfos[1] = PacketDecoder.SignalPrice(
            bytes32(signalIDEth),
            0
        );

        PacketDecoder.Packet memory packet = PacketDecoder.Packet(
            1,
            2,
            "eth",
            "0xe00F1f85abDB2aF6760759547d450da68CE66Bb1",
            signalPriceInfos,
            1728440480
        );

        PacketDecoder.TssMessage memory tssMessage = PacketDecoder.TssMessage(
            0x78512D24E95216DC140F557181A03631715A023424CBAD94601F3546CDFC3DE4,
            1728440480,
            2,
            PacketDecoder.EncoderType.FixedPoint,
            packet
        );

        return tssMessage;
    }

    constructor() {}
}
