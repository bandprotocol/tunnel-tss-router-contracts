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
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;

    function setUp() public {
        tssVerifier = new TssVerifier(address(this));
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
            1
        );

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(
            address(tunnelRouter),
            1,
            keccak256("bandchain"),
            keccak256("eth"),
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

    function testDepositWithdrawDeactiveContract() public {
        // deposit
        uint balanceVaultBefore = address(vault).balance;

        packetConsumer.deposit{value: 0.01 ether}();

        assertEq(
            vault.balance(packetConsumer.tunnelId(), address(packetConsumer)),
            0.01 ether
        );
        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
        assertEq(
            tunnelRouter.isActive(
                packetConsumer.tunnelId(),
                address(packetConsumer)
            ),
            false
        );

        // withdraw
        packetConsumer.withdraw(0.01 ether);
        assertEq(
            vault.balance(packetConsumer.tunnelId(), address(packetConsumer)),
            0
        );
        assertEq(address(vault).balance, balanceVaultBefore);
    }

    function testDepositWithdrawActiveContract() public {
        // activate + deposit
        uint balanceVaultBefore = address(vault).balance;

        packetConsumer.activate{value: 0.01 ether}(2);

        assertEq(
            vault.balance(packetConsumer.tunnelId(), address(packetConsumer)),
            0.01 ether
        );
        assertEq(address(vault).balance, balanceVaultBefore + 0.01 ether);
        assertEq(
            tunnelRouter.isActive(
                packetConsumer.tunnelId(),
                address(packetConsumer)
            ),
            true
        );

        // withdraw
        vm.expectRevert(IVault.InsufficientRemainingBalance.selector);
        packetConsumer.withdraw(0.01 ether);

        assertEq(
            tunnelRouter.isActive(
                packetConsumer.tunnelId(),
                address(packetConsumer)
            ),
            true
        );
    }

    receive() external payable {}
}
