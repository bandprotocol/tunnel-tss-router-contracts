// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IDataConsumer.sol";
import "./interfaces/ITunnelRouter.sol";

import "./libraries/PacketDecoder.sol";
import "./TssVerifier.sol";

contract PacketConsumer is IDataConsumer, Ownable2Step {
    // A price object that being stored for each signal ID.
    struct Price {
        uint64 price;
        int64 timestamp;
    }

    // The tunnel router contract.
    address public immutable tunnelRouter;
    // The hash originator of the feeds price data that this contract consumes.
    bytes32 public immutable hashOriginator;
    // the tunnel ID that this contract is consuming.
    uint64 public immutable tunnelID;
    // The mapping from signal ID to the latest price object.
    mapping(bytes32 => Price) public prices;

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert OnlyTunnelRouter();
        }
        _;
    }

    constructor(
        address tunnelRouter_,
        bytes32 hashOriginator_,
        uint64 tunnelID_,
        address initialOwner
    ) Ownable(initialOwner) {
        tunnelRouter = tunnelRouter_;
        hashOriginator = hashOriginator_;
        tunnelID = tunnelID_;
    }

    /**
     * @dev See {IDataConsumer-process}.
     */
    function process(
        PacketDecoder.TssMessage memory data
    ) external onlyTunnelRouter {
        if (data.hashOriginator != hashOriginator) {
            revert InvalidHashOriginator();
        }

        PacketDecoder.Packet memory packet = data.packet;
        for (uint256 i = 0; i < packet.signals.length; i++) {
            prices[packet.signals[i].signal] = Price({
                price: packet.signals[i].price,
                timestamp: packet.timestamp
            });

            emit UpdateSignalPrice(
                packet.signals[i].signal,
                packet.signals[i].price,
                packet.timestamp
            );
        }
    }

    /**
     * @dev See {IDataConsumer-activate}.
     */
    function activate(uint64 latestSeq) external payable onlyOwner {
        ITunnelRouter(tunnelRouter).activate{value: msg.value}(
            tunnelID,
            latestSeq
        );
    }

    /**
     * @dev See {IDataConsumer-deactivate}.
     */
    function deactivate() external onlyOwner {
        ITunnelRouter(tunnelRouter).deactivate(tunnelID);

        // send the remaining balance to the caller.
        uint256 balance = address(this).balance;
        (bool ok, ) = payable(msg.sender).call{value: balance}("");
        if (!ok) {
            revert FailSendTokens(msg.sender);
        }
    }

    /**
     * @dev See {IDataConsumer-deposit}.
     */
    function deposit() external payable {
        ITunnelRouter(tunnelRouter).deposit{value: msg.value}(
            tunnelID,
            address(this)
        );
    }

    receive() external payable {}
}
