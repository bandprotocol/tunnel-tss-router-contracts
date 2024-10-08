// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/BandReserve.sol";
import "../src/TssVerifier.sol";
import "../src/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "./helper/Constants.sol";
import "./helper/TssSignerHelper.sol";

contract RelayFullLoopTest is Test, Constants {
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    BandReserve bandReserve;

    function setUp() public {
        tssVerifier = new TssVerifier(0x00, address(this));
        tssVerifier.addPubKeyByOwner(CURRENT_GROUP_PARITY, CURRENT_GROUP_PX);

        bandReserve = new BandReserve();
        bandReserve.initialize(address(this));
        vm.deal(address(bandReserve), 10 ether);

        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(
            tssVerifier,
            bandReserve,
            "eth",
            address(this),
            75000,
            50000,
            50000,
            1
        );

        address[] memory whitelistAddrs = new address[](1);
        whitelistAddrs[0] = address(tunnelRouter);

        bandReserve.setWhitelist(whitelistAddrs, true);

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(
            address(tunnelRouter),
            0x95C07FC70EB214B432CC70A9CFA044AEB532577C0B6F7B1AAB2F6E5A7D030E92,
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

    function testRelayMessageConsumerHasEnoughFund() public {
        // set latest nonce.
        packetConsumer.deactivate();
        packetConsumer.reactivate(1);

        vm.deal(address(packetConsumer), 10 ether);

        uint relayerBalance = address(this).balance;
        uint currentGas = gasleft();
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
        uint gasUsed = currentGas - gasleft();
        assertEq(tunnelRouter.nonces(address(packetConsumer)), 2);
        assertEq(tunnelRouter.isInactive(address(packetConsumer)), false);

        uint feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint gasUsedDuringProcessMsg = feeGain /
            tunnelRouter.gasFee() -
            tunnelRouter.additionalGas();

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
        // set latest nonce.
        packetConsumer.deactivate();
        packetConsumer.reactivate(1);

        uint relayerBalance = address(this).balance;

        uint currentGas = gasleft();
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
        uint gasUsed = currentGas - gasleft();

        assertEq(tunnelRouter.nonces(address(packetConsumer)), 2);
        assertEq(tunnelRouter.isInactive(address(packetConsumer)), true);

        uint feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint gasUsedDuringProcessMsg = feeGain /
            tunnelRouter.gasFee() -
            tunnelRouter.additionalGas();

        console.log(
            "gas used during process message: ",
            gasUsedDuringProcessMsg
        );
        console.log(
            "gas used during others step: ",
            gasUsed - gasUsedDuringProcessMsg
        );
    }

    function testRelayInvalidNonce() public {
        vm.expectRevert("TunnelRouter: !nonce");
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testRelayInactiveTargetContract() public {
        packetConsumer.deactivate();

        vm.expectRevert("TunnelRouter: !active");
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testRelayBandReserveNotEnough() public {
        // set latest nonce.
        packetConsumer.deactivate();
        packetConsumer.reactivate(1);

        vm.deal(address(bandReserve), 0 ether);

        vm.expectRevert("BandReserve: Fail to send eth");
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            SIGNATURE_NONCE_ADDR,
            MESSAGE_SIGNATURE
        );
    }

    function testReactivateAlreadyActive() public {
        vm.expectRevert("TunnelRouter: !inactive");
        packetConsumer.reactivate(1);
    }

    receive() external payable {}
}
