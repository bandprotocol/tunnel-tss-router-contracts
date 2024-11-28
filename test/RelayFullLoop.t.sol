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

contract RelayFullLoopTest is Test, Constants {
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;

    function setUp() public {
        tssVerifier = new TssVerifier(86400, address(this));
        tssVerifier.addPubKeyByOwner(0, CURRENT_GROUP_PARITY, CURRENT_GROUP_PX);

        vault = new Vault();
        vault.initialize(address(this), address(0x00), "laozi-mainnet");
        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(tssVerifier, vault, address(this), 75000, 75000, 1, "laozi-mainnet");

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs =
            abi.encode(address(tunnelRouter), keccak256("bandchain"), keccak256("testnet-evm"), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);

        packetConsumer = PacketConsumer(payable(packetConsumerAddr));
        packetConsumer.setTunnelId(1);

        // set latest nonce.
        packetConsumer.activate{value: 0.01 ether}(0);
    }

    function testRelayMessageConsumerNotDeactivate() public {
        uint256 relayerBalance = address(this).balance;
        uint256 currentGas = gasleft();
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
        uint256 gasUsed = currentGas - gasleft();

        bytes32 originatorHash = Originator.hash(keccak256(bytes("laozi-mainnet")), 1, address(packetConsumer));
        assertEq(tunnelRouter.sequence(originatorHash), 1);
        assertEq(tunnelRouter.isActive(originatorHash), true);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain / tunnelRouter.gasFee() - tunnelRouter.additionalGasUsed();

        console.log("gas used during process message: ", gasUsedDuringProcessMsg);
        console.log("gas used during others step: ", gasUsed - gasUsedDuringProcessMsg);
    }

    function testRelayMessageConsumerWithDeactivate() public {
        uint256 relayerBalance = address(this).balance;
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(50 gwei));

        uint256 currentGas = gasleft();
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
        uint256 gasUsed = currentGas - gasleft();

        bytes32 originatorHash = Originator.hash(keccak256(bytes("laozi-mainnet")), 1, address(packetConsumer));
        assertEq(tunnelRouter.sequence(originatorHash), 1);
        assertEq(tunnelRouter.isActive(originatorHash), false);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain / tunnelRouter.gasFee() - tunnelRouter.additionalGasUsed();

        console.log("gas used during process message: ", gasUsedDuringProcessMsg);
        console.log("gas used during others step: ", gasUsed - gasUsedDuringProcessMsg);
    }

    function testRelayInvalidSequence() public {
        packetConsumer.deactivate();

        packetConsumer.activate{value: 0.01 ether}(3);

        bytes memory expectedErr = abi.encodeWithSelector(ITunnelRouter.InvalidSequence.selector, 4, 1);
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
    }

    function testRelayInactiveTunnel() public {
        packetConsumer.deactivate();

        bytes memory expectedErr =
            abi.encodeWithSelector(ITunnelRouter.InactiveTunnel.selector, address(packetConsumer));
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
    }

    function testRelayVaultNotEnoughToken() public {
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(1 ether));

        vm.expectRevert(); // underflow error
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
    }

    function testReactivateAlreadyActive() public {
        bytes memory expectedErr = abi.encodeWithSelector(ITunnelRouter.ActiveTunnel.selector, address(packetConsumer));
        vm.expectRevert(expectedErr);
        packetConsumer.activate(1);
    }

    receive() external payable {}
}
