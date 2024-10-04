// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IDataConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./PacketDecoder.sol";
import "./TssVerifier.sol";

contract PacketConsumer is IDataConsumer, PacketDecoder, Ownable2Step {
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

    /// @dev Process the feeds price data from the TunnelRouter.
    /// @param message The encoded message that contains the feeds price data.
    function process(bytes calldata message) external onlyTunnelRouter {
        TssMessage memory tssMessage = _decodeTssMessage(message);
        require(
            tssMessage.hashOriginator == hashOriginator,
            "PacketConsumer: Invalid hash originator"
        );

        Packet memory packet = tssMessage.packet;

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

    /// @dev transfer fee to the contract.
    /// @param amount The amount of requested fee to be transferred to tunnelRouter contract.
    function collectFee(uint amount) external onlyTunnelRouter {
        require(
            address(this).balance >= amount,
            "PacketConsumer: insufficient balance"
        );

        (bool ok, bytes memory result) = tunnelRouter.call{value: amount}("");
        if (!ok) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (result.length < 68) revert("PacketConsumer: Fail to send fee");
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }
    }

    /// @dev reactivate the target contract with the latest nonce.
    /// @param latestNonce The new latest nonce of the target contract.
    function reactivate(uint64 latestNonce) external payable onlyOwner {
        ITunnelRouter(tunnelRouter).reactivate{value: msg.value}(latestNonce);
    }

    /// @dev deactivate the contract to the tunnelRouter.
    function deactivate() external onlyOwner {
        ITunnelRouter(tunnelRouter).deactivate();
    }

    receive() external payable {}

    fallback() external payable {}
}
