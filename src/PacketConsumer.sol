// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IDataConsumer.sol";
import "./interfaces/ITunnelRouter.sol";

import "./libraries/PacketDecoder.sol";
import "./TssVerifier.sol";

contract PacketConsumer is IDataConsumer, Ownable2Step {
    using PacketDecoder for bytes;

    // A price object that being stored for each signal ID.
    struct Price {
        uint64 price;
        int64 timestamp;
    }

    // The tunnel router contract.
    address public immutable tunnelRouter;
    // The hash originator of the feeds price data that this contract consumes.
    bytes32 public immutable hashOriginator;
    // The mapping from signal ID to the latest price object.
    mapping(bytes32 => Price) public prices;

    event UpdateSignalPrice(
        bytes32 indexed signalID,
        uint64 price,
        int64 timestamp
    );

    modifier onlyTunnelRouter() {
        require(
            msg.sender == tunnelRouter,
            "PacketConsumer: only tunnelRouter"
        );
        _;
    }

    constructor(
        address tunnelRouter_,
        bytes32 hashOriginator_,
        address initialOwner
    ) Ownable(initialOwner) {
        tunnelRouter = tunnelRouter_;
        hashOriginator = hashOriginator_;
    }

    /**
     * @dev See {IDataConsumer-process}.
     */
    function process(bytes calldata message) external onlyTunnelRouter {
        PacketDecoder.TssMessage memory tssMessage = message.decodeTssMessage();
        require(
            tssMessage.hashOriginator == hashOriginator,
            "PacketConsumer: !hashOriginator"
        );

        PacketDecoder.Packet memory packet = tssMessage.packet;

        for (uint i = 0; i < packet.signals.length; i++) {
            prices[packet.signals[i].signal] = Price({
                price: packet.signals[i].price,
                timestamp: packet.timestmap
            });

            emit UpdateSignalPrice(
                packet.signals[i].signal,
                packet.signals[i].price,
                packet.timestmap
            );
        }
    }

    /**
     * @dev See {IDataConsumer-activate}.
     */
    function activate(
        uint64 tunnelID,
        uint64 latestSeq
    ) external payable onlyOwner {
        ITunnelRouter(tunnelRouter).activate{value: msg.value}(
            tunnelID,
            latestSeq
        );
    }

    /**
     * @dev See {IDataConsumer-deactivate}.
     */
    function deactivate(uint64 tunnelID) external onlyOwner {
        ITunnelRouter(tunnelRouter).deactivate(tunnelID);

        // send the remaining balance to the caller.
        uint balance = address(this).balance;
        (bool ok, ) = payable(msg.sender).call{value: balance}("");
        require(ok, "PacketConsumer: !send");
    }

    receive() external payable {}
}
