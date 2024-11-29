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
    PacketConsumer public packetConsumer;

    function chainId() public pure returns (string memory) {
        return "eth";
    }

    function setUp() public {
        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs =
            abi.encode(address(this), keccak256("bandchain"), keccak256("testnet-evm"), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));
        packetConsumer.setTunnelId(1);
    }

    function testProcess() public {
        PacketDecoder.TssMessage memory data = DECODED_TSS_MESSAGE();
        PacketDecoder.Packet memory packet = data.packet;

        packetConsumer.process(data);

        // check prices mapping.
        (uint64 price, int64 timestamp) = packetConsumer.prices(packet.signals[0].signal);
        assertEq(price, packet.signals[0].price);
        assertEq(timestamp, packet.timestamp);
    }

    function testProcessInvalidHashOriginator() public {
        PacketDecoder.TssMessage memory data = DECODED_TSS_MESSAGE();

        // fix originator hash.
        data.hashOriginator = 0x00;
        bytes memory expectedErr = abi.encodeWithSelector(IDataConsumer.InvalidHashOriginator.selector);
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
        tssVerifier = new TssVerifier(86400, address(this));
        tssVerifier.addPubKeyByOwner(0, CURRENT_GROUP_PARITY, CURRENT_GROUP_PX);

        vault = new Vault();
        vault.initialize(
            address(this),
            address(0x00),
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            0x541111248b45b7a8dc3f5579f630e74cb01456ea6ac067d3f4d793245a255155
        );

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
        bytes memory packetConsumerArgs =
            abi.encode(address(tunnelRouter), keccak256("bandchain"), keccak256("testnet-evm"), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));

        // set latest nonce.
        packetConsumer.activate{value: 0.01 ether}(1);
    }

    function testDeposit() public {
        uint256 depositedAmtBefore = vault.balance(packetConsumer.tunnelId(), address(packetConsumer));
        uint256 balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}();

        assertEq(vault.balance(packetConsumer.tunnelId(), address(packetConsumer)), depositedAmtBefore + 0.01 ether);

        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
    }

    function testSetTunnelID() public {
        packetConsumer.setTunnelId(1);
        assertEq(packetConsumer.tunnelId(), 1);
    }
}
