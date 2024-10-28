// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";
import "./helper/TssSignerHelper.sol";

contract RelayFullLoopTest is Test, Constants {
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;
    TssSignerHelper helper;

    function setUp() public {
        helper = new TssSignerHelper();
        tssVerifier = new TssVerifier(address(this));
        tssVerifier.addPubKeyByOwner(CURRENT_GROUP_PARITY - 25, CURRENT_PUBKEY_TIMESTAMP, CURRENT_GROUP_PX);
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

    function testRelayMessageConsumerHasEnoughFund() public {
        uint256 relayerBalance = address(this).balance;
        vm.warp(CURRENT_PUBKEY_TIMESTAMP);

        uint256 currentGas = gasleft();
        tunnelRouter.relay(
            CURRENT_GROUP_PARITY,
            CURRENT_PUBKEY_TIMESTAMP,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE,
            TSS_RAW_MESSAGE
        );
        uint256 gasUsed = currentGas - gasleft();
        assertEq(tunnelRouter.sequence(1, address(packetConsumer)), 2);
        assertEq(tunnelRouter.isActive(1, address(packetConsumer)), true);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain /
            tunnelRouter.gasFee() -
            tunnelRouter.additionalGasUsed();

        console.log(
            "gas used during process message: ",
            gasUsedDuringProcessMsg
        );
        console.log(
            "gas used during others step: ",
            gasUsed - gasUsedDuringProcessMsg
        );
    }

    function testRelayMessageConsumerUseReserve() public {
        uint256 relayerBalance = address(this).balance;

        vault.setMinimumActiveBalance(1 ether);
        vm.warp(CURRENT_PUBKEY_TIMESTAMP);

        uint256 currentGas = gasleft();
        tunnelRouter.relay(
            CURRENT_GROUP_PARITY,
            CURRENT_PUBKEY_TIMESTAMP,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE,
            TSS_RAW_MESSAGE
        );
        uint256 gasUsed = currentGas - gasleft();

        assertEq(tunnelRouter.sequence(1, address(packetConsumer)), 2);
        assertEq(tunnelRouter.isActive(1, address(packetConsumer)), false);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain /
            tunnelRouter.gasFee() -
            tunnelRouter.additionalGasUsed();

        console.log(
            "gas used during process message: ",
            gasUsedDuringProcessMsg
        );
        console.log(
            "gas used during others step: ",
            gasUsed - gasUsedDuringProcessMsg
        );
    }

    function testRelayInvalidSequence() public {
        packetConsumer.deactivate();

        packetConsumer.activate{value: 0.01 ether}(0);

        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.InvalidSequence.selector,
            1,
            2
        );
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(
            CURRENT_GROUP_PARITY,
            CURRENT_PUBKEY_TIMESTAMP,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE,
            TSS_RAW_MESSAGE
        );
    }

    function testRelayInactiveTargetContract() public {
        packetConsumer.deactivate();

        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.Inactive.selector,
            address(packetConsumer)
        );
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(
            CURRENT_GROUP_PARITY,
            CURRENT_PUBKEY_TIMESTAMP,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE,
            TSS_RAW_MESSAGE
        );
    }

    function testRelayVaultNotEnoughToken() public {
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(1 ether));

        vm.expectRevert(); // underflow error
        tunnelRouter.relay(
            CURRENT_GROUP_PARITY,
            CURRENT_PUBKEY_TIMESTAMP,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE,
            TSS_RAW_MESSAGE
        );
    }

    function testReactivateAlreadyActive() public {
        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.Active.selector,
            address(packetConsumer)
        );
        vm.expectRevert(expectedErr);
        packetConsumer.activate(1);
    }

    receive() external payable {}
}
