// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/PacketConsumerFactory.sol";
import "../src/PacketConsumer.sol";
import "../src/router/GasPriceTunnelRouter.sol";
import "../src/Vault.sol";
import "../src/libraries/Originator.sol";
import "./helper/Constants.sol";
import "./helper/MockTssVerifier.sol";
import "./helper/MockPacketConsumer.sol";

contract PacketConsumerMultipleTunnelTest is Test, Constants {
    MockPacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    MockTssVerifier tssVerifier;
    Vault vault;

    function setUp() public {
        // deploy mock tss verifier.
        tssVerifier = new MockTssVerifier();

        // deploy vault.
        vault = new Vault();
        vault.initialize(address(this), address(0x00));

        // deploy and setup tunnel router.
        tunnelRouter = new GasPriceTunnelRouter();
        tunnelRouter.initialize(
            tssVerifier,
            vault,
            address(this),
            75000,
            100000,
            1,
            keccak256("bandchain"),
            keccak256("testnet-evm")
        );
        address[] memory whitelist = new address[](1);
        whitelist[0] = address(this);
        tunnelRouter.setWhitelist(whitelist, true);

        // set tunnel router to vault.
        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet consumer.
        packetConsumer = new MockPacketConsumer(
            address(tunnelRouter),
            address(this)
        );

        // activate tunnelId 1 and 2.
        for (uint64 i = 1; i <= 2; i++) {
            packetConsumer.activate{value: 0.01 ether}(i, 0);

            bytes32 originatorHash = Originator.hash(
                tunnelRouter.sourceChainIdHash(),
                i,
                tunnelRouter.targetChainIdHash(),
                address(packetConsumer)
            );
            assertEq(tunnelRouter.isActive(originatorHash), true);
        }
    }

    function testMultipleTunnel() public {
        for (uint64 i = 1; i <= 2; i++) {
            PacketConsumer.Price memory p;
            BaseTunnelRouter.TunnelInfo memory tunnelInfo;

            // verify tunnel info before relay.
            tunnelInfo = tunnelRouter.tunnelInfo(i, address(packetConsumer));
            assertEq(tunnelInfo.isActive, true);
            assertEq(tunnelInfo.latestSequence, 0);

            // verify price of the contract before relay.
            p = packetConsumer.prices("CS:BTC-USD");
            assertEq(p.price, 0);
            assertEq(p.timestamp, 0);
            p = packetConsumer.prices("CS:ETH-USD");
            assertEq(p.price, 0);
            assertEq(p.timestamp, 0);
            p = packetConsumer.prices("CS:BAND-USD");
            assertEq(p.price, 0);
            assertEq(p.timestamp, 0);

            // generate a new message for a relay.
            bytes32 originatorHash = Originator.hash(
                tunnelRouter.sourceChainIdHash(),
                i,
                tunnelRouter.targetChainIdHash(),
                address(packetConsumer)
            );
            bytes memory message = abi.encodePacked(
                originatorHash,
                hex"00000000674c2ae0",
                hex"0000000000000001",
                hex"d3813e0ccba0ad5a",
                hex"0000000000000000000000000000000000000000000000000000000000000020",
                hex"0000000000000000000000000000000000000000000000000000000000000001",
                hex"0000000000000000000000000000000000000000000000000000000000000060",
                hex"00000000000000000000000000000000000000000000000000000000674c2ae0",
                hex"0000000000000000000000000000000000000000000000000000000000000003",
                hex"0000000000000000000000000000000000000000000043533a4254432d555344",
                hex"0000000000000000000000000000000000000000000000000000000000008765",
                hex"0000000000000000000000000000000000000000000043533a4554482d555344",
                hex"0000000000000000000000000000000000000000000000000000000000004321",
                hex"00000000000000000000000000000000000000000043533a42414e442d555344",
                hex"0000000000000000000000000000000000000000000000000000000000001234"
            );

            // use mock signature as we skip the tss verification part.
            address mockRandomAddr = address(0);
            uint256 mockSignature = 0;
            tunnelRouter.relay(message, mockRandomAddr, mockSignature);

            // verify the price after relay.
            p = packetConsumer.prices("CS:BTC-USD");
            assertEq(p.price, 34661);
            assertEq(p.timestamp, 1733044960);
            p = packetConsumer.prices("CS:ETH-USD");
            assertEq(p.price, 17185);
            assertEq(p.timestamp, 1733044960);
            p = packetConsumer.prices("CS:BAND-USD");
            assertEq(p.price, 4660);
            assertEq(p.timestamp, 1733044960);

            // verify tunnel info after relay.
            tunnelInfo = tunnelRouter.tunnelInfo(i, address(packetConsumer));
            assertEq(tunnelInfo.isActive, true);
            assertEq(tunnelInfo.latestSequence, 1);

            // reset the price of the contract.
            packetConsumer.setPrice(_toBytes32("CS:BTC-USD"), 0, 0);
            packetConsumer.setPrice(_toBytes32("CS:ETH-USD"), 0, 0);
            packetConsumer.setPrice(_toBytes32("CS:BAND-USD"), 0, 0);
        }
    }

    function testInvalidTunnelId() public {
        // generate a new message for a relay.
        bytes32 originatorHash = Originator.hash(
            tunnelRouter.sourceChainIdHash(),
            3,
            tunnelRouter.targetChainIdHash(),
            address(packetConsumer)
        );

        bytes memory message = abi.encodePacked(
            originatorHash,
            hex"00000000674c2ae0",
            hex"0000000000000001",
            hex"d3813e0ccba0ad5a",
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000060",
            hex"00000000000000000000000000000000000000000000000000000000674c2ae0",
            hex"0000000000000000000000000000000000000000000000000000000000000003",
            hex"0000000000000000000000000000000000000000000043533a4254432d555344",
            hex"0000000000000000000000000000000000000000000000000000000000008765",
            hex"0000000000000000000000000000000000000000000043533a4554482d555344",
            hex"0000000000000000000000000000000000000000000000000000000000004321",
            hex"00000000000000000000000000000000000000000043533a42414e442d555344",
            hex"0000000000000000000000000000000000000000000000000000000000001234"
        );

        // use mock signature as we skip the tss verification part.
        address mockRandomAddr = address(0);
        uint256 mockSignature = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                ITunnelRouter.TunnelNotActive.selector,
                originatorHash
            )
        );
        tunnelRouter.relay(message, mockRandomAddr, mockSignature);
    }

    function _toBytes32(string memory s) internal view returns (bytes32) {
        return packetConsumer.stringToRightAlignedBytes32(s);
    }

    receive() external payable {}
}
