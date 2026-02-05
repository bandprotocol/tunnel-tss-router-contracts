// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./PacketConsumerBase.sol";
import "./interfaces/IPacketConsumer.sol";
import "./libraries/PacketDecoder.sol";

contract PacketConsumer is PacketConsumerBase {

    // Mapping between a signal ID and its corresponding latest price object.
    mapping(bytes32 => Price) internal _prices;

    constructor(
        address tunnelRouter_
    ) PacketConsumerBase(tunnelRouter_) {
    }

    /**
     * @dev See {IPacketConsumer-getPrice}.
     */
    function getPrice(string calldata _signalId) external view returns (Price memory) {
        Price memory price = _prices[stringToRightAlignedBytes32(_signalId)];
        if (price.price == 0) {
            revert SignalIdNotAvailable(_signalId);
        }
        return price;
    }

    /**
     * @dev See {IPacketConsumer-getPriceBatch}.
     */
    function getPriceBatch(string[] calldata _signalIds) external view returns (Price[] memory) {
        Price[] memory priceList = new Price[](_signalIds.length);
        for (uint i = 0; i < _signalIds.length; i++) {
            Price memory price = _prices[stringToRightAlignedBytes32(_signalIds[i])];
            if (price.price == 0) {
                revert SignalIdNotAvailable(_signalIds[i]);
            }
            priceList[i] = price;
        }
        return priceList;
    }

    /**
     * @dev See {IPacketConsumer-process}.
     */
    function process(
        PacketDecoder.TssMessage memory data
    ) external onlyTunnelRouter {
        PacketDecoder.Packet memory packet = data.packet;
        if (data.encoderType != PacketDecoder.EncoderType.FixedPoint) revert InvalidEncoderType();
        for (uint256 i = 0; i < packet.signals.length; i++) {
            _prices[packet.signals[i].signal] = Price({
                price: packet.signals[i].price,
                timestamp: packet.timestamp
            });
        }
    }
}
