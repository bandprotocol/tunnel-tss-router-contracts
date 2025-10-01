// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/libraries/PacketDecoder.sol";
import "./TssSignerHelper.sol";

contract Constants is Test, TssSignerHelper {
    uint8 immutable CURRENT_GROUP_PARITY;
    uint256 immutable CURRENT_GROUP_PX;
    address immutable MOCK_SENDER;
    address immutable MOCK_VALID_GAS_FEE_UPDATER_ROLE;
    address immutable MOCK_INVALID_GAS_FEE_UPDATER_ROLE;
    address immutable SIGNATURE_NONCE_ADDR;
    uint256 immutable MESSAGE_SIGNATURE;

    bytes constant TSS_RAW_MESSAGE =
        abi.encodePacked(
            hex"1930634c04eaace73b84b572782f354be5c6c84233d24c0ede853409d89c3585",
            hex"00000000674c2ae0",
            hex"0000000000000001",
            hex"d3813e0ccba0ad5a",
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000060",
            hex"00000000000000000000000000000000000000000000000000000000674c2ae0",
            hex"0000000000000000000000000000000000000000000000000000000000000003",
            hex"0000000000000000000000000000000000000000000043533a4254432d555344",
            hex"0000000000000000000000000000000000000000000000000000000000008765",
            hex"0000000000000000000000000000000000000000000043533a4554482d555344",
            hex"0000000000000000000000000000000000000000000000000000000000004321",
            hex"00000000000000000000000000000000000000000043533a42414e442d555344",
            hex"0000000000000000000000000000000000000000000000000000000000001234"
        );

    constructor() {
        uint256 privateKey = 0x1988eae609ced9c1121aa2fdb8ba899de41b4970a3cee58ad5692b5187e702b2;
        MOCK_SENDER = vm.addr(privateKey);
        privateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
        MOCK_VALID_GAS_FEE_UPDATER_ROLE = vm.addr(privateKey);
        privateKey = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
        MOCK_INVALID_GAS_FEE_UPDATER_ROLE = vm.addr(privateKey);
        (CURRENT_GROUP_PARITY, CURRENT_GROUP_PX) = getPubkey(privateKey);
        (SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE) = sign(
            CURRENT_GROUP_PARITY,
            CURRENT_GROUP_PX,
            getRandomNonce(privateKey),
            keccak256(TSS_RAW_MESSAGE),
            privateKey
        );
        assertEq(vm.addr(getRandomNonce(privateKey)), SIGNATURE_NONCE_ADDR);
    }

    function DECODED_TSS_MESSAGE()
        public
        pure
        returns (PacketDecoder.TssMessage memory)
    {
        PacketDecoder.SignalPrice[]
            memory signalPriceInfos = new PacketDecoder.SignalPrice[](3);
        bytes memory signalIDBtc = abi.encodePacked(
            hex"00000000000000000000000000000000000000000000",
            "CS:BTC-USD"
        );
        signalPriceInfos[0] = PacketDecoder.SignalPrice(
            bytes32(signalIDBtc),
            0x8765
        );

        bytes memory signalIDEth = abi.encodePacked(
            hex"00000000000000000000000000000000000000000000",
            "CS:ETH-USD"
        );
        signalPriceInfos[1] = PacketDecoder.SignalPrice(
            bytes32(signalIDEth),
            0x4321
        );

        bytes memory signalIDBand = abi.encodePacked(
            hex"000000000000000000000000000000000000000000",
            "CS:BAND-USD"
        );
        signalPriceInfos[2] = PacketDecoder.SignalPrice(
            bytes32(signalIDBand),
            0x1234
        );

        PacketDecoder.Packet memory packet = PacketDecoder.Packet(
            1,
            signalPriceInfos,
            1733044960
        );

        PacketDecoder.TssMessage memory tssMessage = PacketDecoder.TssMessage(
            0x1930634c04eaace73b84b572782f354be5c6c84233d24c0ede853409d89c3585,
            1733044960,
            1,
            PacketDecoder.EncoderType.FixedPoint,
            packet
        );

        return tssMessage;
    }
}
