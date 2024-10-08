// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract PacketDecoder {
    bytes4 private constant _FIXED_POINT_ENCODER_SELECTOR = 0xcba0ad5a; // keccak256("FixedPointABI");
    bytes4 private constant _TICK_ENCODER_SELECTOR = 0xdb99b2b3; // keccak256("TickABI");
    bytes4 private constant _TUNNEL_ORIGINATOR_SELECTOR = 0xa466d313;

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

        Packet memory packet = _decodePacket(message);

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
        Packet memory packet = abi.decode(message[88:], (Packet));
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

    function _toHashOriginator(
        uint64 tunnelID,
        address targetAddr,
        string memory chainID
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _TUNNEL_ORIGINATOR_SELECTOR,
                    bytes1(0x08),
                    _encodeUintToBytes(uint(tunnelID)),
                    bytes1(0x12),
                    _encodeUintToBytes(42), // "0x..."
                    Strings.toChecksumHexString(targetAddr),
                    bytes1(0x1A),
                    _encodeUintToBytes(bytes(chainID).length),
                    chainID
                )
            );
    }

    // returns the minimum number of bits required to represent x; the result is 0 for x == 0.
    function _bitLength(uint x) internal pure returns (uint8 r) {
        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            r += 128;
        }
        if (x >= 0x10000000000000000) {
            x >>= 64;
            r += 64;
        }
        if (x >= 0x100000000) {
            x >>= 32;
            r += 32;
        }
        if (x >= 0x10000) {
            x >>= 16;
            r += 16;
        }
        if (x >= 0x100) {
            x >>= 8;
            r += 8;
        }
        if (x >= 0x10) {
            x >>= 4;
            r += 4;
        }
        if (x >= 0x4) {
            x >>= 2;
            r += 2;
        }
        if (x >= 0x2) r += 1;
        if (x >= 0x1) r += 1;
    }

    function _encodeUintToBytes(uint v) internal pure returns (bytes memory) {
        uint length = (_bitLength(v) + 6) / 7;

        bytes memory data = new bytes(length);
        uint offset;
        assembly {
            offset := 0
            for {

            } gt(v, 0x7f) {

            } {
                // Store the current 7 bits with continuation flag (0x80)
                mstore8(add(data, add(0x20, offset)), or(and(v, 0x7f), 0x80))
                v := shr(7, v) // Right shift by 7 bits
                offset := add(offset, 1) // Increment offset
            }
            mstore8(add(data, add(0x20, offset)), v)
        }

        return data;
    }
}
