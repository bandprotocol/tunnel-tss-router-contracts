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
            75000,
            1,
            keccak256("bandchain"),
            keccak256("testnet-evm")
        );

        vault.setTunnelRouter(address(tunnelRouter));

        vm.txGasPrice(1);

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
    }

    function testDepositWithdrawInactiveContract() public {
        // deposit
        uint256 balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}(tunnelId);

        bytes32 originatorHash = Originator.hash(
            keccak256("bandchain"),
            tunnelId,
            keccak256("testnet-evm"),
            address(packetConsumer)
        );

        assertEq(vault.balance(tunnelId, address(packetConsumer)), 0.01 ether);
        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
        assertEq(tunnelRouter.isActive(originatorHash), false);

        // withdraw
        packetConsumer.withdraw(tunnelId, 0.01 ether);
        assertEq(vault.balance(tunnelId, address(packetConsumer)), 0);
        assertEq(address(vault).balance, balanceVaultBefore);
    }

    function testDepositWithdrawActiveContract() public {
        // activate + deposit
        uint256 balanceVaultBefore = address(vault).balance;

        bytes32 originatorHash = Originator.hash(
            keccak256("bandchain"),
            tunnelId,
            keccak256("testnet-evm"),
            address(packetConsumer)
        );

        packetConsumer.activate{value: 0.01 ether}(tunnelId, 2);

        assertEq(vault.balance(tunnelId, address(packetConsumer)), 0.01 ether);
        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
        assertEq(tunnelRouter.isActive(originatorHash), true);

        // withdraw
        vm.expectRevert(IVault.WithdrawnAmountExceedsThreshold.selector);
        packetConsumer.withdraw(tunnelId, 0.01 ether);

        assertEq(tunnelRouter.isActive(originatorHash), true);
    }

    receive() external payable {}
}
