// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/BandReserve.sol";
import "../src/TssVerifier.sol";
import "../src/TunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "./helper/Constants.sol";
import "./helper/TssSignerHelper.sol";

contract RelayFullLoopTest is Test, Constants {
    PacketConsumer packetConsumer;
    TunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    BandReserve bandReserve;

    function setUp() public {
        tssVerifier = new TssVerifier(0x00, address(this));
        tssVerifier.addPubKeyByOwner(
            2,
            0x22CA06770AB5FD60D3EA06E9B93200225E7F9B4D73B09B681BF9617D101001F3
        );

        bandReserve = new BandReserve();
        bandReserve.initialize(address(this));
        vm.deal(address(bandReserve), 10 ether);

        tunnelRouter = new TunnelRouter();
        tunnelRouter.initialize(
            tssVerifier,
            bandReserve,
            address(this),
            1,
            75000,
            50000,
            50000
        );

        address[] memory whitelistAddrs = new address[](1);
        whitelistAddrs[0] = address(tunnelRouter);

        bandReserve.setWhitelist(whitelistAddrs, true);

        packetConsumer = new PacketConsumer(
            address(tunnelRouter),
            0xA37F90F0501F931F161F3C51421BED9A59819335D8D0F009D0E1357A863AC96B,
            address(this)
        );
    }

    function testRelayMessageConsumerHasEnoughFund() public {
        // set latest nonce.
        packetConsumer.deactivate();
        packetConsumer.reactivate(18);

        vm.deal(address(packetConsumer), 10 ether);

        uint relayerBalance = address(this).balance;
        uint currentGas = gasleft();
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            address(0x3c3CA8c8A0bED1AdB3d690c1134A63dB699eC516),
            0x20E410DEBC3EB7C29ADB312165C00A759A5EE877CFF5FDDA17502C0AE34198A0
        );
        uint gasUsed = currentGas - gasleft();
        assertEq(tunnelRouter.nonces(address(packetConsumer)), 19);
        assertEq(tunnelRouter.isInactive(address(packetConsumer)), false);

        uint feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint gasUsedDuringProcessMsg = feeGain /
            tunnelRouter.gasPrice() -
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
        packetConsumer.reactivate(18);

        uint relayerBalance = address(this).balance;

        uint currentGas = gasleft();
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            address(0x3c3CA8c8A0bED1AdB3d690c1134A63dB699eC516),
            0x20E410DEBC3EB7C29ADB312165C00A759A5EE877CFF5FDDA17502C0AE34198A0
        );
        uint gasUsed = currentGas - gasleft();

        assertEq(tunnelRouter.nonces(address(packetConsumer)), 19);
        assertEq(tunnelRouter.isInactive(address(packetConsumer)), true);

        uint feeGain = address(this).balance - relayerBalance;
        assertGt(feeGain, 0);

        uint gasUsedDuringProcessMsg = feeGain /
            tunnelRouter.gasPrice() -
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
            address(0x3c3CA8c8A0bED1AdB3d690c1134A63dB699eC516),
            0x20E410DEBC3EB7C29ADB312165C00A759A5EE877CFF5FDDA17502C0AE34198A0
        );
    }

    function testRelayInactiveTargetContract() public {
        packetConsumer.deactivate();

        vm.expectRevert("TunnelRouter: !active");
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            address(0x3c3CA8c8A0bED1AdB3d690c1134A63dB699eC516),
            0x20E410DEBC3EB7C29ADB312165C00A759A5EE877CFF5FDDA17502C0AE34198A0
        );
    }

    function testRelayBandReserveNotEnough() public {
        // set latest nonce.
        packetConsumer.deactivate();
        packetConsumer.reactivate(18);

        vm.deal(address(bandReserve), 0 ether);

        vm.expectRevert("BandReserve: Fail to send eth");
        tunnelRouter.relay(
            TSS_RAW_MESSAGE,
            packetConsumer,
            address(0x3c3CA8c8A0bED1AdB3d690c1134A63dB699eC516),
            0x20E410DEBC3EB7C29ADB312165C00A759A5EE877CFF5FDDA17502C0AE34198A0
        );
    }

    function testReactivateAlreadyActive() public {
        vm.expectRevert("TunnelRouter: !inactive");
        packetConsumer.reactivate(18);
    }

    receive() external payable {}
}
