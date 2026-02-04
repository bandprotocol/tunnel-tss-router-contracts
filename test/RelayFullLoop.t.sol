// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/libraries/PacketDecoder.sol";
import "../src/interfaces/IPacketConsumer.sol";
import "../src/interfaces/ITunnelRouter.sol";
import "../src/libraries/Originator.sol";
import "../src/router/GasPriceTunnelRouter.sol";
import "../src/router/L1RouterGasCalculator.sol";
import "../src/PacketConsumer.sol";
import "../src/PacketConsumerTick.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";
import "./helper/TssSignerHelper.sol";

contract RelayFullLoopTest is Test, Constants {
    PacketConsumer packetConsumer;
    PacketConsumerTick packetConsumerTick;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;
    bytes32 originatorHash;
    bytes32 originatorHashTick;
    mapping(uint256 => PacketDecoder.SignalPrice) referencePrices;
    int64 referenceTimestamp;
    uint64 constant tunnelId = 1;
    uint64 constant tunnelIdTick = 2;

    function setUp() public {
        tssVerifier = new TssVerifier(86400, 0x00, address(this));
        tssVerifier.addPubKeyByOwner(
            0,
            CURRENT_GROUP_PARITY - 25,
            CURRENT_GROUP_PX
        );

        vault = new Vault();
        vault.initialize(address(this), address(0x00));
        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(
            tssVerifier,
            vault,
            75000 * 1e18,
            14000,
            175000,
            10,
            keccak256("bandchain"),
            keccak256("testnet-evm"),
            true
        );
        address[] memory whitelist = new address[](1);
        whitelist[0] = address(this);
        tunnelRouter.grantRelayer(whitelist);

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
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 0);

        originatorHash = Originator.hash(
            tunnelRouter.sourceChainIdHash(),
            tunnelId,
            tunnelRouter.targetChainIdHash(),
            address(packetConsumer)
        );
        assertEq(tunnelRouter.isActive(originatorHash), true);

        address packetConsumerTickAddr = makeAddr("PacketConsumerTick");
        deployCodeTo(
            "PacketConsumerTick.sol:PacketConsumerTick",
            packetConsumerArgs,
            packetConsumerTickAddr
        );

        packetConsumerTick = PacketConsumerTick(payable(packetConsumerTickAddr));

        // set latest nonce.
        packetConsumerTick.activate{value: 0.01 ether}(tunnelIdTick, 0);

        originatorHashTick = Originator.hash(
            tunnelRouter.sourceChainIdHash(),
            tunnelIdTick,
            tunnelRouter.targetChainIdHash(),
            address(packetConsumerTick)
        );
        assertEq(tunnelRouter.isActive(originatorHashTick), true);

        PacketDecoder.TssMessage memory tssm = this.decodeTssMessage(
            TSS_RAW_MESSAGE
        );
        assertTrue(tssm.packet.timestamp > 0);
        assertTrue(tssm.packet.signals.length > 0);
        referenceTimestamp = tssm.packet.timestamp;
        for (uint256 i = 0; i < tssm.packet.signals.length; i++) {
            assertTrue(tssm.packet.signals[i].price > 0);
            referencePrices[i] = tssm.packet.signals[i];
        }

        vm.deal(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE, 10 ether);
        vm.deal(MOCK_INVALID_TUNNEL_ACTIVATOR_ROLE, 10 ether);
    }

    function decodeTssMessage(
        bytes calldata message
    ) public pure returns (PacketDecoder.TssMessage memory) {
        return PacketDecoder.decodeTssMessage(message);
    }

    function encodeTssMessage(PacketDecoder.TssMessage memory tssMessage) public pure returns (bytes memory) {
        bytes8 encoderSelector;
        if (tssMessage.encoderType == PacketDecoder.EncoderType.FixedPoint) {
            encoderSelector = 0xd3813e0ccba0ad5a;
        } else if (tssMessage.encoderType == PacketDecoder.EncoderType.Tick) {
            encoderSelector = 0xd3813e0cdb99b2b3;
        } else {
            revert IPacketConsumer.InvalidEncoderType();
        }
        
        bytes memory packetBytes = abi.encode(tssMessage.packet);
        
        return abi.encodePacked(
            tssMessage.originatorHash,
            bytes8(uint64(tssMessage.sourceTimestamp)),
            bytes8(uint64(tssMessage.signingId)),
            encoderSelector,
            packetBytes
        );
    }

    function testRelayMessageConsumerActivated() public {
        // gasPrice is lower than the user-defined gas fee
        uint256 gasPrice = 1;
        vm.txGasPrice(gasPrice);

        PacketConsumer.Price memory p;

        // Before
        bytes memory expectedErr = abi.encodeWithSelector(IPacketConsumer.SignalIdNotAvailable.selector, "CS:BTC-USD");
        vm.expectRevert(expectedErr);
        packetConsumer.getPrice("CS:BTC-USD");
        expectedErr = abi.encodeWithSelector(IPacketConsumer.SignalIdNotAvailable.selector, "CS:ETH-USD");
        vm.expectRevert(expectedErr);
        packetConsumer.getPrice("CS:ETH-USD");
        expectedErr = abi.encodeWithSelector(IPacketConsumer.SignalIdNotAvailable.selector, "CS:BAND-USD");
        vm.expectRevert(expectedErr);
        packetConsumer.getPrice("CS:BAND-USD");

        uint256 relayerBalance = address(this).balance;
        uint256 currentGas = gasleft();
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHash, 1, true);
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
        uint256 gasUsed = currentGas - gasleft();

        // After
        p = packetConsumer.getPrice("CS:BTC-USD");
        assertEq(p.price, referencePrices[0].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.getPrice("CS:ETH-USD");
        assertEq(p.price, referencePrices[1].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.getPrice("CS:BAND-USD");
        assertEq(p.price, referencePrices[2].price);
        assertEq(p.timestamp, referenceTimestamp);

        assertEq(tunnelRouter.sequence(originatorHash), 1);
        assertEq(tunnelRouter.isActive(originatorHash), true);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain / gasPrice - tunnelRouter.additionalGasForCalldata(0);

        console.log(
            "gas used during process message: ",
            gasUsedDuringProcessMsg
        );
        console.log(
            "gas used during others step: ",
            gasUsed - gasUsedDuringProcessMsg
        );
    }

    function testRelayMessageConsumerDeactivated() public {
        // gasPrice is more than the user-defined gas fee
        uint256 gasPrice = 100 gwei;
        vm.txGasPrice(gasPrice);

        PacketConsumer.Price memory p;
        uint256 relayerBalance = address(this).balance;
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(50 gwei));

        // Before
        bytes memory expectedErr = abi.encodeWithSelector(IPacketConsumer.SignalIdNotAvailable.selector, "CS:BTC-USD");
        vm.expectRevert(expectedErr);
        p = packetConsumer.getPrice("CS:BTC-USD");
        expectedErr = abi.encodeWithSelector(IPacketConsumer.SignalIdNotAvailable.selector, "CS:ETH-USD");
        vm.expectRevert(expectedErr);
        p = packetConsumer.getPrice("CS:ETH-USD");
        expectedErr = abi.encodeWithSelector(IPacketConsumer.SignalIdNotAvailable.selector, "CS:BAND-USD");
        vm.expectRevert(expectedErr);
        p = packetConsumer.getPrice("CS:BAND-USD");

        uint256 currentGas = gasleft();
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHash, 1, true);
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
        uint256 gasUsed = currentGas - gasleft();

        // After
        p = packetConsumer.getPrice("CS:BTC-USD");
        assertEq(p.price, referencePrices[0].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.getPrice("CS:ETH-USD");
        assertEq(p.price, referencePrices[1].price);
        assertEq(p.timestamp, referenceTimestamp);
        p = packetConsumer.getPrice("CS:BAND-USD");
        assertEq(p.price, referencePrices[2].price);
        assertEq(p.timestamp, referenceTimestamp);

        assertEq(tunnelRouter.sequence(originatorHash), 1);
        console.log("tunnelRouter.additionalGasForCalldata(0) =", tunnelRouter.additionalGasForCalldata(0));
        assertEq(tunnelRouter.isActive(originatorHash), false);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = feeGain / tunnelRouter.gasFee() - tunnelRouter.additionalGasForCalldata(0);

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
        packetConsumer.deactivate(tunnelId);

        packetConsumer.activate{value: 0.01 ether}(tunnelId, 3);

        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.InvalidSequence.selector,
            4,
            1
        );
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testRelayInactiveTunnel() public {
        packetConsumer.deactivate(tunnelId);

        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.TunnelNotActive.selector,
            originatorHash
        );
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testRelayVaultNotEnoughToken() public {
        tunnelRouter.setGasFee(GasPriceTunnelRouter.GasFeeInfo(1 ether));
        vm.txGasPrice(1 ether);

        vm.expectRevert(); // underflow error
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testReactivateAlreadyActive() public {
        bytes memory expectedErr = abi.encodeWithSelector(
            ITunnelRouter.TunnelAlreadyActive.selector,
            originatorHash
        );
        vm.expectRevert(expectedErr);
        packetConsumer.activate(tunnelId, 1);
    }

    function testSenderNotRelayerRole() public {
        vm.expectRevert();
        vm.prank(MOCK_SENDER);

        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testNonAdminCannotGrantGasFeeUpdater() public {
        address[] memory accounts = new address[](1);
        accounts[0] = MOCK_VALID_GAS_FEE_UPDATER_ROLE;

        vm.prank(MOCK_VALID_GAS_FEE_UPDATER_ROLE);
        vm.expectRevert();
        tunnelRouter.grantGasFeeUpdater(accounts);
    }

    function testGrantGasFeeUpdaterRoleAllowsSetGasFee() public {
        vm.prank(MOCK_VALID_GAS_FEE_UPDATER_ROLE);
        vm.expectRevert();
        tunnelRouter.setGasFee(
            GasPriceTunnelRouter.GasFeeInfo({gasPrice: 2 gwei})
        );

        address[] memory accounts = new address[](1);
        accounts[0] = MOCK_VALID_GAS_FEE_UPDATER_ROLE;
        tunnelRouter.grantGasFeeUpdater(accounts);

        vm.prank(MOCK_VALID_GAS_FEE_UPDATER_ROLE);
        tunnelRouter.setGasFee(
            GasPriceTunnelRouter.GasFeeInfo({gasPrice: 2 gwei})
        );

        vm.prank(MOCK_INVALID_GAS_FEE_UPDATER_ROLE);
        vm.expectRevert();
        tunnelRouter.setGasFee(
            GasPriceTunnelRouter.GasFeeInfo({gasPrice: 2 gwei})
        );
    }

    function testRevokeGasFeeUpdaterRolePreventsSetGasFee() public {
        address[] memory accounts = new address[](1);
        accounts[0] = MOCK_VALID_GAS_FEE_UPDATER_ROLE;
        tunnelRouter.grantGasFeeUpdater(accounts);

        vm.prank(MOCK_VALID_GAS_FEE_UPDATER_ROLE);
        tunnelRouter.setGasFee(
            GasPriceTunnelRouter.GasFeeInfo({gasPrice: 2 gwei})
        );

        tunnelRouter.revokeGasFeeUpdater(accounts);

        vm.prank(MOCK_VALID_GAS_FEE_UPDATER_ROLE);
        vm.expectRevert();
        tunnelRouter.setGasFee(
            GasPriceTunnelRouter.GasFeeInfo({gasPrice: 2 gwei})
        );
    }

    function testRelayCalldataSizeTooLarge() public {
        bytes memory relayMessage = abi.encodeWithSelector(tunnelRouter.relay.selector, TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
        uint256 maxCalldataByte = 10;
        tunnelRouter.setMaxCalldataBytes(maxCalldataByte);

        bytes memory expectedErr = abi.encodeWithSelector(L1RouterGasCalculator.CalldataSizeTooLarge.selector, relayMessage.length, maxCalldataByte);
        vm.expectRevert(expectedErr);
        tunnelRouter.relay(TSS_RAW_MESSAGE, SIGNATURE_NONCE_ADDR, MESSAGE_SIGNATURE);
    }

    // ============= TUNNEL ACTIVATOR ROLE TESTS ================

    function testNonAdminCannotGrantTunnelActivatorRole() public {
        address[] memory accounts = new address[](1);
        accounts[0] = MOCK_VALID_TUNNEL_ACTIVATOR_ROLE;

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.grantTunnelActivatorRole(accounts);
    }

    function testGrantTunnelActivatorRoleAllowsActivateAndDeactivateTunnel() public {
        // Should not be able to activate or deactivate tunnel before having the role
        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 10);

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.deactivate(tunnelId);

        // Grant the activator role
        address[] memory accounts = new address[](1);
        accounts[0] = MOCK_VALID_TUNNEL_ACTIVATOR_ROLE;
        packetConsumer.grantTunnelActivatorRole(accounts);

        // Activate should succeed with the role (deactivate first to allow)
        packetConsumer.deactivate(tunnelId);

        vm.prank(MOCK_INVALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 20);

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        // Should now be able to activate and deactivate
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 20);
        assertEq(tunnelRouter.isActive(originatorHash), true);

        vm.prank(MOCK_INVALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.deactivate(tunnelId);

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        packetConsumer.deactivate(tunnelId);
        assertEq(tunnelRouter.isActive(originatorHash), false);
    }

    function testRevokeTunnelActivatorRolePreventsActivateAndDeactivateTunnel() public {
        // Grant role first
        address[] memory accounts = new address[](1);
        accounts[0] = MOCK_VALID_TUNNEL_ACTIVATOR_ROLE;
        packetConsumer.grantTunnelActivatorRole(accounts);

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        packetConsumer.deactivate(tunnelId);

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 99);

        // Revoke the activator role
        packetConsumer.revokeTunnelActivatorRole(accounts);

        // Now, it should revert for both activate and deactivate
        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.deactivate(tunnelId);

        vm.prank(MOCK_VALID_TUNNEL_ACTIVATOR_ROLE);
        vm.expectRevert();
        packetConsumer.activate{value: 0.01 ether}(tunnelId, 123);
    }

    function testRelayMessageConsumerTickActivated() public {
        // List symbols first (required for PacketConsumerTick)
        string[] memory symbols = new string[](3);
        symbols[0] = "CS:BTC-USD";
        symbols[1] = "CS:ETH-USD";
        symbols[2] = "CS:BAND-USD";
        packetConsumerTick.listing(symbols);

        // gasPrice is lower than the user-defined gas fee
        vm.txGasPrice(1);

        // Before: expect price queries to revert
        vm.expectRevert();
        packetConsumerTick.getPrice("CS:BTC-USD");
        vm.expectRevert();
        packetConsumerTick.getPrice("CS:ETH-USD");
        vm.expectRevert();
        packetConsumerTick.getPrice("CS:BAND-USD");

        // Construct TSS message for tick consumer using DECODED_TSS_MESSAGE_PRICE_TICK
        PacketDecoder.TssMessage memory tssMessageDecoded = DECODED_TSS_MESSAGE_PRICE_TICK();
        // Replace originatorHash with originatorHashTick
        tssMessageDecoded.originatorHash = originatorHashTick;
        
        // Encode the TssMessage to raw bytes format
        bytes memory tssMessageTick = this.encodeTssMessage(tssMessageDecoded);

        // Sign the message
        (address signatureNonceAddrTick, uint256 messageSignatureTick) = signTssm(
            tssMessageTick,
            PRIVATE_KEY_1
        );

        uint256 relayerBalance = address(this).balance;
        uint256 currentGas = gasleft();
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHashTick, 1, true);
        tunnelRouter.relay(
            tssMessageTick,
            signatureNonceAddrTick,
            messageSignatureTick
        );
        uint256 gasUsed = currentGas - gasleft();

        // After: prices should be available and derived from ticks
        PacketDecoder.Packet memory packet = tssMessageDecoded.packet;
        PacketConsumerTick.Price memory p = packetConsumerTick.getPrice("CS:BTC-USD");
        assertEq(p.price, uint64(packetConsumerTick.getPriceFromTick(packet.signals[0].price)));
        assertEq(p.timestamp, packet.timestamp);
        
        p = packetConsumerTick.getPrice("CS:ETH-USD");
        assertEq(p.price, uint64(packetConsumerTick.getPriceFromTick(packet.signals[1].price)));
        assertEq(p.timestamp, packet.timestamp);
        
        p = packetConsumerTick.getPrice("CS:BAND-USD");
        assertEq(p.price, uint64(packetConsumerTick.getPriceFromTick(packet.signals[2].price)));
        assertEq(p.timestamp, packet.timestamp);

        assertEq(tunnelRouter.sequence(originatorHashTick), 1);
        assertEq(tunnelRouter.isActive(originatorHashTick), true);

        uint256 feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint256 gasUsedDuringProcessMsg = (feeGain / tx.gasprice) - tunnelRouter.additionalGasForCalldata(0);

        console.log("gas used during process message (tick): ", gasUsedDuringProcessMsg);
        console.log("gas used during others step (tick): ", gasUsed - gasUsedDuringProcessMsg);
    }
    
    // ============= REFUNDABLE TESTS ================

    function testNoFeeRefundWhenRefundableIsFalse() public {
        // Set refundable to false
        tunnelRouter.setRefundable(false);
        assertEq(tunnelRouter.refundable(), false);

        uint256 vaultBalanceBefore = vault.getBalanceByOriginatorHash(originatorHash);

        // Relay a message
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHash, 1, true);
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );

        // Vault balance should not change (no refund)
        uint256 vaultBalanceAfter = vault.getBalanceByOriginatorHash(originatorHash);
        assertEq(vaultBalanceAfter, vaultBalanceBefore, "vault balance should not change when refundable is false");

        // Tunnel should still be active
        assertEq(tunnelRouter.isActive(originatorHash), true);
    }

    function testRefundableFalseTunnelStaysActiveWithLowBalance() public {
        // Set refundable to false
        tunnelRouter.setRefundable(false);
        
        // Get the minimum balance threshold
        uint256 threshold = tunnelRouter.minimumBalanceThreshold();
        
        // Deactivate and reactivate with balance just above threshold
        packetConsumer.deactivate(tunnelId);
        packetConsumer.activate{value: threshold + 1 wei}(tunnelId, 0);
        
        // Verify tunnel is active
        assertEq(tunnelRouter.isActive(originatorHash), true);
        
        // Relay a message - should succeed without deactivating
        vm.expectEmit();
        emit ITunnelRouter.MessageProcessed(originatorHash, 1, true);
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
        
        // Tunnel should still be active even though balance might be below threshold
        assertEq(tunnelRouter.isActive(originatorHash), true);
    }

    function testRefundableFalseActivationSucceedsWithLowBalance() public {
        // Set refundable to false
        tunnelRouter.setRefundable(false);
        
        // Deactivate the tunnel first
        packetConsumer.deactivate(tunnelId);
        
        // Activate with balance below threshold - should succeed when refundable is false
        packetConsumer.activate{value: 0 wei}(tunnelId, 0);
        assertEq(tunnelRouter.isActive(originatorHash), true);
    }

    receive() external payable {}
}
