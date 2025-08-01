// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/libraries/PacketDecoder.sol";
import "../src/interfaces/ITunnelRouter.sol";
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
    bytes32 originatorHash;
    mapping(uint256 => PacketDecoder.SignalPrice) referencePrices;
    int64 referenceTimestamp;

    function setUp() public {
        tssVerifier = new TssVerifier(86400, 0x00, address(this));
        tssVerifier.addPubKeyByOwner(0, CURRENT_GROUP_PARITY - 25, CURRENT_GROUP_PX);

        vault = new Vault();
        vault.initialize(address(this), address(0x00));
        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(
            tssVerifier, vault, address(this), 75000, 75000, 1, keccak256("bandchain"), keccak256("testnet-evm")
        );
        address[] memory whitelist = new address[](1);
        whitelist[0] = address(this);
        tunnelRouter.setWhitelist(whitelist, true);

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(address(tunnelRouter), address(this));
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo("PacketConsumer.sol:PacketConsumer", packetConsumerArgs, packetConsumerAddr);

        packetConsumer = PacketConsumer(payable(packetConsumerAddr));
        packetConsumer.setTunnelId(1);

        // set latest nonce.
        packetConsumer.activate{value: 0.01 ether}(0);

        originatorHash = Originator.hash(
            tunnelRouter.sourceChainIdHash(), 1, tunnelRouter.targetChainIdHash(), address(packetConsumer)
        );
        assertEq(tunnelRouter.isActive(originatorHash), true);

        PacketDecoder.TssMessage memory tssm = this.decodeTssMessage(TSS_RAW_MESSAGE);
        assertTrue(tssm.packet.timestamp > 0);
        assertTrue(tssm.packet.signals.length > 0);
        referenceTimestamp = tssm.packet.timestamp;
        for (uint256 i = 0; i < tssm.packet.signals.length; i++) {
            assertTrue(tssm.packet.signals[i].price > 0);
            referencePrices[i] = tssm.packet.signals[i];
        }
    }

    function decodeTssMessage(bytes calldata message) public pure returns (PacketDecoder.TssMessage memory) {
        return PacketDecoder.decodeTssMessage(message);
    }

    function testRelayMessageConsumerActivated() public {
        PacketConsumer.Price memory p;

        // Before
        p = packetConsumer.prices("CS:BTC-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);
        p = packetConsumer.prices("CS:ETH-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);
        p = packetConsumer.prices("CS:BAND-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);

        uint256 relayerBalance = address(this).balance;
        uint256 currentGas = gasleft();
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHash, 1, true);
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
        uint256 gasUsed = currentGas - gasleft();

        // After
        p = packetConsumer.prices("CS:BTC-USD");
        assertEq(p.price, referencePrices[0].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.prices("CS:ETH-USD");
        assertEq(p.price, referencePrices[1].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.prices("CS:BAND-USD");
        assertEq(p.price, referencePrices[2].price);
        assertEq(p.timestamp, referenceTimestamp);

        assertEq(tunnelRouter.sequence(originatorHash), 1);
        assertEq(tunnelRouter.isActive(originatorHash), true);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain / tunnelRouter.gasFee() - tunnelRouter.additionalGasUsed();

        console.log("gas used during process message: ", gasUsedDuringProcessMsg);
        console.log("gas used during others step: ", gasUsed - gasUsedDuringProcessMsg);
    }

    function testRelayMessageConsumerDeactivated() public {
        PacketConsumer.Price memory p;
        uint256 relayerBalance = address(this).balance;
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(50 gwei));

        // Before
        p = packetConsumer.prices("CS:BTC-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);
        p = packetConsumer.prices("CS:ETH-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);
        p = packetConsumer.prices("CS:BAND-USD");
        assertEq(p.price, 0);
        assertEq(p.timestamp, 0);

        uint256 currentGas = gasleft();
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHash, 1, true);
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
        uint256 gasUsed = currentGas - gasleft();

        // After
        p = packetConsumer.prices("CS:BTC-USD");
        assertEq(p.price, referencePrices[0].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.prices("CS:ETH-USD");
        assertEq(p.price, referencePrices[1].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.prices("CS:BAND-USD");
        assertEq(p.price, referencePrices[2].price);
        assertEq(p.timestamp, referenceTimestamp);

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

        bytes memory expectedErr = abi.encodeWithSelector(ITunnelRouter.TunnelNotActive.selector, originatorHash);
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
    }

    function testRelayVaultNotEnoughToken() public {
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(1 ether));

        vm.expectRevert(); // underflow error
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
    }

    function testReactivateAlreadyActive() public {
        bytes memory expectedErr = abi.encodeWithSelector(ITunnelRouter.TunnelAlreadyActive.selector, originatorHash);
        vm.expectRevert(expectedErr);
        packetConsumer.activate(1);
    }

    function testSenderNotInWhitelist() public {
        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.SenderNotWhitelisted.selector,
            MOCK_SENDER
        );

        vm.expectRevert(expectedErr);
        vm.prank(MOCK_SENDER);

        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testSetWhitelistInvalidSender() public {
        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.InvalidSenderAddress.selector
        );

        vm.expectRevert(expectedErr);

        address[] memory whitelist = new address[](1);
        whitelist[0] = address(0);
        tunnelRouter.setWhitelist(whitelist, true);
    }

    receive() external payable {}
}
