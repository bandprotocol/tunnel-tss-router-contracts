// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/libraries/PacketDecoder.sol";
import "../src/router/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";

contract PacketConsumerMockTunnelRouterTest is Test, Constants {
    PacketConsumer packetConsumer;

    function setUp() public {
        packetConsumer = new PacketConsumer(
            address(this),
            0x78512D24E95216DC140F557181A03631715A023424CBAD94601F3546CDFC3DE4,
            uint64(1),
            address(this)
        );
    }

    function testProcess() public {
        PacketDecoder.TssMessage memory data = DECODED_TSS_MESSAGE();
        PacketDecoder.Packet memory packet = data.packet;

        packetConsumer.process(data);

        // check prices mapping.
        (uint64 price, int64 timestamp) = packetConsumer.prices(
            packet.signals[0].signal
        );
        assertEq(price, packet.signals[0].price);
        assertEq(timestamp, packet.timestamp);
    }

    function testProcessInvalidHashOriginator() public {
        PacketDecoder.TssMessage memory data = DECODED_TSS_MESSAGE();

        // fix originator hash.
        data.hashOriginator = 0x00;
        bytes memory expectedErr = abi.encodeWithSelector(
            IDataConsumer.InvalidHashOriginator.selector
        );
        vm.expectRevert(expectedErr);
        packetConsumer.process(data);
    }
}

contract PacketConsumerTest is Test, Constants {
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;

    function setUp() public {
        tssVerifier = new TssVerifier(address(this));
        tssVerifier.addPubKeyByOwner(CURRENT_GROUP_PARITY, CURRENT_GROUP_PX);

        vault = new Vault();
        vault.initialize(address(this), address(0x00));

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
            packetConsumer.tunnelId(),
            address(packetConsumer)
        );
        uint balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}();

        assertEq(
            vault.balance(packetConsumer.tunnelId(), address(packetConsumer)),
            depositedAmtBefore + 0.01 ether
        );

        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
    }
}
