// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/interfaces/IPacketConsumer.sol";
import "../src/libraries/PacketDecoder.sol";
import "../src/router/GasPriceTunnelRouter.sol";
import "../src/PacketConsumerTick.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";

contract PacketConsumerTickMockTunnelRouterTest is Test, Constants {
    PacketConsumerTick public packetConsumerTick;
    uint64 constant tunnelId = 1;

    function setUp() public {
        // Deploy PacketConsumerTick with a mock tunnel router address (this contract)
        packetConsumerTick = new PacketConsumerTick(address(this));
    }

    function testStringToRightAlignedBytes32() public {
        string memory s;

        s = "";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        s = "0";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "01";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"000000000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "012";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "01234";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "012345";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123456";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "01234567";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "012345678";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123456789";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123456789a";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000000000000000000000", s)
        );
        s = "0123456789ab";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000000000000000000000", s)
        );
        s = "0123456789abc";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000000000000000000000", s)
        );
        s = "0123456789abcd";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000000000000000", s)
        );
        s = "0123456789abcde";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000000000000000", s)
        );
        s = "0123456789abcdef";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000000000000000", s)
        );
        s = "0123456789abcdefg";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000000000", s)
        );
        s = "0123456789abcdefgh";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000000000", s)
        );
        s = "0123456789abcdefghi";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000000000", s)
        );
        s = "0123456789abcdefghij";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000", s)
        );
        s = "0123456789abcdefghijk";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000", s)
        );
        s = "0123456789abcdefghijkl";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000", s)
        );
        s = "0123456789abcdefghijklm";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000", s)
        );
        s = "0123456789abcdefghijklmn";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000", s)
        );
        s = "0123456789abcdefghijklmno";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000", s)
        );
        s = "0123456789abcdefghijklmnop";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000", s)
        );
        s = "0123456789abcdefghijklmnopq";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000", s)
        );
        s = "0123456789abcdefghijklmnopqr";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000", s)
        );
        s = "0123456789abcdefghijklmnopqrs";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000", s)
        );
        s = "0123456789abcdefghijklmnopqrst";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000", s)
        );
        s = "0123456789abcdefghijklmnopqrstu";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00", s)
        );
        s = "0123456789abcdefghijklmnopqrstuv";
        assertEq(
            abi.encodePacked(packetConsumerTick.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"", s)
        );

        s = "0123456789abcdefghijklmnopqrstuvwx";
        vm.expectRevert(
            abi.encodeWithSelector(
                IPacketConsumer.StringInputExceedsBytes32.selector,
                s
            )
        );
        packetConsumerTick.stringToRightAlignedBytes32(s);

        s = "0123456789abcdefghijklmnopqrstuvwxy";
        vm.expectRevert(
            abi.encodeWithSelector(
                IPacketConsumer.StringInputExceedsBytes32.selector,
                s
            )
        );
        packetConsumerTick.stringToRightAlignedBytes32(s);

        s = "0123456789abcdefghijklmnopqrstuvwxyz";
        vm.expectRevert(
            abi.encodeWithSelector(
                IPacketConsumer.StringInputExceedsBytes32.selector,
                s
            )
        );
        packetConsumerTick.stringToRightAlignedBytes32(s);
    }

    function testProcessAndGetPrice() public {
        // List symbols first so that process can succeed
        string[] memory symbols = new string[](3);
        symbols[0] = "CS:BTC-USD";
        symbols[1] = "CS:ETH-USD";
        symbols[2] = "CS:BAND-USD";
        packetConsumerTick.listing(symbols);

        PacketConsumerTick.Price memory p;
        PacketDecoder.TssMessage memory data = DECODED_TSS_MESSAGE_PRICE_TICK();
        PacketDecoder.Packet memory packet = data.packet;

        // Before: expect price queries to revert
        vm.expectRevert();
        p = packetConsumerTick.getPrice("CS:BTC-USD");

        // Process prices (msg.sender == tunnelRouter == address(this))
        packetConsumerTick.process(data);

        // After: prices should be available and derived from ticks
        p = packetConsumerTick.getPrice("CS:BTC-USD");
        assertEq(
            p.price,
            uint64(packetConsumerTick.getPriceFromTick(packet.signals[0].price))
        );
        assertEq(p.timestamp, packet.timestamp);

        p = packetConsumerTick.getPrice("CS:ETH-USD");
        assertEq(
            p.price,
            uint64(packetConsumerTick.getPriceFromTick(packet.signals[1].price))
        );
        assertEq(p.timestamp, packet.timestamp);

        // Batch prices
        string[] memory signalIds = new string[](2);
        signalIds[0] = "CS:BTC-USD";
        signalIds[1] = "CS:ETH-USD";

        PacketConsumerTick.Price[] memory prices = packetConsumerTick.getPriceBatch(
            signalIds
        );
        for (uint256 i = 0; i < 2; i++) {
            assertEq(
                prices[i].price,
                uint64(
                    packetConsumerTick.getPriceFromTick(
                        packet.signals[i].price
                    )
                )
            );
            assertEq(prices[i].timestamp, packet.timestamp);
        }
    }
}

contract PacketConsumerTickTest is Test, Constants {
    PacketConsumerTick packetConsumerTick;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;
    uint64 constant tunnelId = 1;

    function setUp() public {
        tssVerifier = new TssVerifier(86400, 0x00, address(this));
        tssVerifier.addPubKeyByOwner(0, CURRENT_GROUP_PARITY, CURRENT_GROUP_PX);

        vault = new Vault();
        vault.initialize(address(this), address(0x00));

        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(
            tssVerifier,
            vault,
            75000 * 1e18,
            14000,
            50000,
            1,
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            0x541111248b45b7a8dc3f5579f630e74cb01456ea6ac067d3f4d793245a255155
        );

        vault.setTunnelRouter(address(tunnelRouter));

        // Deploy PacketConsumerTick pointing to the real tunnel router
        packetConsumerTick = new PacketConsumerTick(address(tunnelRouter));
    }

    function testDeposit() public {
        uint256 depositedAmtBefore = vault.balance(
            tunnelId,
            address(packetConsumerTick)
        );
        uint256 balanceVaultBefore = address(vault).balance;

        packetConsumerTick.deposit{value: 0.01 ether}(tunnelId);

        assertEq(
            vault.balance(tunnelId, address(packetConsumerTick)),
            depositedAmtBefore + 0.01 ether
        );

        assertEq(
            address(vault).balance,
            balanceVaultBefore + 0.01 ether
        );
    }
}

