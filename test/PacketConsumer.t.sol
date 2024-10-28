// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/libraries/PacketDecoder.sol";
import "../src/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";
import "./helper/MockTunnelRouter.sol";

contract PacketConsumerMockTunnelTest is Test, Constants {
    PacketConsumer packetConsumer;
    MockTunnelRouter tunnelRouter;

    function setUp() public {
        tunnelRouter = new MockTunnelRouter();
        packetConsumer = new PacketConsumer(
            address(tunnelRouter),
            0x78512D24E95216DC140F557181A03631715A023424CBAD94601F3546CDFC3DE4,
            uint64(1),
            address(this)
        );
    }

    function testProcess() public {
        tunnelRouter.relay(TSS_RAW_MESSAGE, packetConsumer);

        PacketDecoder.TssMessage memory tssMessage = DECODED_TSS_MESSAGE();
        PacketDecoder.Packet memory packet = tssMessage.packet;

        // check prices mapping.
        (uint64 price, int64 timestamp) = packetConsumer.prices(
            packet.signals[0].signal
        );
        assertEq(price, packet.signals[0].price);
        assertEq(timestamp, packet.timestmap);
    }

    function testProcessInvalidHashOriginator() public {
        // fix originator hash.
        bytes memory message = TSS_RAW_MESSAGE;
        for (uint256 i = 32; i < 64; i++) {
            message[i] = 0x00;
        }
        vm.expectRevert("PacketConsumer: !hashOriginator");
        tunnelRouter.relay(message, packetConsumer);
    }
}

contract PacketConsumerTest is Test, Constants {
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;

    function setUp() public {
        tssVerifier = new TssVerifier(0x00, address(this));
        tssVerifier.addPubKeyByOwner(CURRENT_GROUP_PARITY, CURRENT_GROUP_PX);

        vault = new Vault();
        vault.initialize(address(this), 0, address(0x00));

        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(
            tssVerifier,
            vault,
            0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0, // keccak256("eth")
            address(this),
            75000,
            50000,
            1
        );

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(
            address(tunnelRouter),
            0x78512D24E95216DC140F557181A03631715A023424CBAD94601F3546CDFC3DE4,
            1,
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
        packetConsumer.activate{value: 0.01 ether}(1);
    }

    function testDeposit() public {
        uint depositedAmtBefore = vault.balance(
            packetConsumer.tunnelID(),
            address(packetConsumer)
        );
        uint balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}();

        assertEq(
            vault.balance(packetConsumer.tunnelID(), address(packetConsumer)),
            depositedAmtBefore + 0.01 ether
        );

        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
    }
}
