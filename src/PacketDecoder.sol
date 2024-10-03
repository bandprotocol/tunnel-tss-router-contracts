// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

abstract contract PacketDecoder {
    bytes4 internal constant _FIXED_POINT_ENCODER_SELECTOR = 0xcba0ad5a; // keccak256("FixedPointABI");
    bytes4 internal constant _TICK_ENCODER_SELECTOR = 0xdb99b2b3; // keccak256("TickABI");

    enum EncoderType {
        UnIdentified,
        FixedPoint,
        Tick
    }

    /// @dev info of signals being attached with the packet.
    struct SignalPrice {
        bytes32 signal;
        uint64 price;
    }

    /// @dev the packet information generated from the tunnel.
    struct Packet {
        uint64 tunnelID;
        uint64 nonce;
        // TODO: require confirmation.
        // address targetAddr;
        // uint chainID;
        SignalPrice[] signals;
        int64 timestmap;
    }

    /// @dev the decoded TSS message structure that being signed by the tss module.
    struct TssMessage {
        bytes32 hashChainID;
        bytes32 hashOriginator;
        uint64 sourceBlockTimestmap;
        uint64 signingID;
        EncoderType encoderType;
        Packet packet;
    }

    /// @dev decode the TSS message from the encoded message.
    /// @param message The encoded message.
    /// @return TssMessage The decoded TSS message object.
    function _decodeTssMessage(
        bytes calldata message
    ) internal pure returns (TssMessage memory) {
        EncoderType encoder = _toEncoderType(bytes4(message[84:88]));

        Packet memory packet = _decodePacket(message[88:]);

        TssMessage memory tssMessage = TssMessage(
            bytes32(message[0:32]),
            bytes32(message[32:64]),
            uint64(bytes8(message[64:72])),
            uint64(bytes8(message[72:80])),
            encoder,
            packet
        );

        return tssMessage;
    }

    /// @dev decode the packet from the encoded message.
    /// @param message The encoded message.
    /// @return Packet The decoded packet object.
    function _decodePacket(
        bytes calldata message
    ) internal pure returns (Packet memory) {
        Packet memory packet = abi.decode(message[176:], (Packet));
        return packet;
    }

    /// @dev convert the selector to the encoder type.
    /// @param selector The selector to be converted.
    /// @return EncoderType The encoder type.
    function _toEncoderType(
        bytes4 selector
    ) internal pure returns (EncoderType) {
        if (selector == _FIXED_POINT_ENCODER_SELECTOR) {
            return EncoderType.FixedPoint;
        } else if (selector == _TICK_ENCODER_SELECTOR) {
            return EncoderType.Tick;
        } else {
            return EncoderType.UnIdentified;
        }
    }
}
