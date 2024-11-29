// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/router/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";
import "./helper/TssSignerHelper.sol";

contract VaultTest is Test, Constants {
    PacketConsumer internal packetConsumer;
    GasPriceTunnelRouter internal tunnelRouter;
    TssVerifier internal tssVerifier;
    Vault internal vault;

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
            75000,
            1,
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            0x541111248b45b7a8dc3f5579f630e74cb01456ea6ac067d3f4d793245a255155
        );

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs =
            abi.encode(address(tunnelRouter), keccak256("bandchain"), keccak256("eth"), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);
        packetConsumer = PacketConsumer(payable(packetConsumerAddr));
    }

    function testDepositWithdrawInactiveContract() public {
        // deposit
        uint256 balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}();

        bytes32 originatorHash = Originator.hash(
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            0x541111248b45b7a8dc3f5579f630e74cb01456ea6ac067d3f4d793245a255155,
            packetConsumer.tunnelId(),
            address(packetConsumer)
        );

        assertEq(vault.balance(packetConsumer.tunnelId(), address(packetConsumer)), 0.01 ether);
        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
        assertEq(tunnelRouter.isActive(originatorHash), false);

        // withdraw
        packetConsumer.withdraw(0.01 ether);
        assertEq(vault.balance(packetConsumer.tunnelId(), address(packetConsumer)), 0);
        assertEq(address(vault).balance, balanceVaultBefore);
    }

    function testDepositWithdrawActiveContract() public {
        // activate + deposit
        uint256 balanceVaultBefore = address(vault).balance;

        bytes32 originatorHash = Originator.hash(
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            0x541111248b45b7a8dc3f5579f630e74cb01456ea6ac067d3f4d793245a255155,
            packetConsumer.tunnelId(),
            address(packetConsumer)
        );

        packetConsumer.activate{value: 0.01 ether}(2);

        assertEq(vault.balance(packetConsumer.tunnelId(), address(packetConsumer)), 0.01 ether);
        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
        assertEq(tunnelRouter.isActive(originatorHash), true);

        // withdraw
        vm.expectRevert(IVault.WithdrawnAmountExceedsThreshold.selector);
        packetConsumer.withdraw(0.01 ether);

        assertEq(tunnelRouter.isActive(originatorHash), true);
    }

    receive() external payable {}
}
