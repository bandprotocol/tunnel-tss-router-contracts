// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/interfaces/IPacketConsumer.sol";
import "../src/libraries/PacketDecoder.sol";
import "../src/router/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";

contract PacketConsumerMockTunnelRouterTest is Test, Constants {
    PacketConsumer public packetConsumer;
    uint64 constant tunnelId = 1;

    function sourceChainIdHash() public pure returns (bytes32) {
        return keccak256("bandchain");
    }

    function targetChainIdHash() public pure returns (bytes32) {
        return keccak256("testnet-evm");
    }

    function setUp() public {
        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(
            address(this),
            address(this)
        );
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo(
            "PacketConsumer.sol:PacketConsumer",
            packetConsumerArgs,
            packetConsumerAddr
        );
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));
    }

    function teststringToRightAlignedBytes32() public {
        string memory s;

        s = "";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        s = "0";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "01";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"000000000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "012";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "01234";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"000000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "012345";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123456";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "01234567";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"000000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "012345678";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"0000000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123456789";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(
                hex"00000000000000000000000000000000000000000000",
                s
            )
        );
        s = "0123456789a";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000000000000000000000", s)
        );
        s = "0123456789ab";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000000000000000000000", s)
        );
        s = "0123456789abc";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000000000000000000000", s)
        );
        s = "0123456789abcd";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000000000000000", s)
        );
        s = "0123456789abcde";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000000000000000", s)
        );
        s = "0123456789abcdef";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000000000000000", s)
        );
        s = "0123456789abcdefg";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000000000", s)
        );
        s = "0123456789abcdefgh";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000000000", s)
        );
        s = "0123456789abcdefghi";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000000000", s)
        );
        s = "0123456789abcdefghij";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000000000", s)
        );
        s = "0123456789abcdefghijk";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000000000", s)
        );
        s = "0123456789abcdefghijkl";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000000000", s)
        );
        s = "0123456789abcdefghijklm";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000000000", s)
        );
        s = "0123456789abcdefghijklmn";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000000000", s)
        );
        s = "0123456789abcdefghijklmno";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000000000", s)
        );
        s = "0123456789abcdefghijklmnop";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000000000", s)
        );
        s = "0123456789abcdefghijklmnopq";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000000000", s)
        );
        s = "0123456789abcdefghijklmnopqr";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00000000", s)
        );
        s = "0123456789abcdefghijklmnopqrs";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"000000", s)
        );
        s = "0123456789abcdefghijklmnopqrst";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"0000", s)
        );
        s = "0123456789abcdefghijklmnopqrstu";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"00", s)
        );
        s = "0123456789abcdefghijklmnopqrstuv";
        assertEq(
            abi.encodePacked(packetConsumer.stringToRightAlignedBytes32(s)),
            abi.encodePacked(hex"", s)
        );

        s = "0123456789abcdefghijklmnopqrstuvwx";
        vm.expectRevert(
            abi.encodeWithSelector(
                IPacketConsumer.StringInputExceedsBytes32.selector,
                s
            )
        );
        packetConsumer.stringToRightAlignedBytes32(s);

        s = "0123456789abcdefghijklmnopqrstuvwxy";
        vm.expectRevert(
            abi.encodeWithSelector(
                IPacketConsumer.StringInputExceedsBytes32.selector,
                s
            )
        );
        packetConsumer.stringToRightAlignedBytes32(s);

        s = "0123456789abcdefghijklmnopqrstuvwxyz";
        vm.expectRevert(
            abi.encodeWithSelector(
                IPacketConsumer.StringInputExceedsBytes32.selector,
                s
            )
        );
        packetConsumer.stringToRightAlignedBytes32(s);
    }

    function testProcess() public {
        PacketConsumer.Price memory p;
        PacketDecoder.TssMessage memory data = DECODED_TSS_MESSAGE();
        PacketDecoder.Packet memory packet = data.packet;

        // check prices mapping.(before)
        p = packetConsumer.prices("CS:BTC-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);

        p = packetConsumer.prices("CS:ETH-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);

        packetConsumer.process(data);

        // check prices mapping.(after)
        p = packetConsumer.prices("CS:BTC-USD");
        assertEq(p.price, packet.signals[0].price);
        assertEq(p.timestamp, packet.timestamp);

        p = packetConsumer.prices("CS:ETH-USD");
        assertEq(p.price, packet.signals[1].price);
        assertEq(p.timestamp, packet.timestamp);
    }
}

contract PacketConsumerTest is Test, Constants {
    PacketConsumer packetConsumer;
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
            address(this),
            75000,
            50000,
            1,
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            0x541111248b45b7a8dc3f5579f630e74cb01456ea6ac067d3f4d793245a255155
        );

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(
            address(tunnelRouter),
            address(this)
        );
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo(
            "PacketConsumer.sol:PacketConsumer",
            packetConsumerArgs,
            packetConsumerAddr
        );
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));

        // set latest nonce.
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 1);
    }

    function testDeposit() public {
        uint256 depositedAmtBefore = vault.balance(
            tunnelId,
            address(packetConsumer)
        );
        uint256 balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}(tunnelId);

        assertEq(
            vault.balance(tunnelId, address(packetConsumer)),
            depositedAmtBefore + 0.01 ether
        );

        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
    }
}
