// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPacketConsumer.sol";

contract PacketConsumerProxy is Ownable {
    IPacketConsumer public packetConsumer;

    constructor(IPacketConsumer _packetConsumer, address _owner) Ownable(_owner) {
        packetConsumer = _packetConsumer;
    }

    /// @dev Updates packet consumer implementation. Only callable by the owner.
    function setPacketConsumer(IPacketConsumer _packetConsumer) public onlyOwner {
        packetConsumer = _packetConsumer;
    }

    /// @dev Returns the price for a given `signalId`, reverting if it does not exist.
    function getPrice(string memory signalId)
        public
        view
        returns (IPacketConsumer.Price memory)
    {
        return packetConsumer.getPrice(signalId);
    }

    /// @dev Returns the prices for the given `signalIds`, reverting if any do not exist.
    function getPriceBatch(string[] memory signalIds)
        public
        view
        returns (IPacketConsumer.Price[] memory)
    {
        return packetConsumer.getPriceBatch(signalIds);
    }
}
