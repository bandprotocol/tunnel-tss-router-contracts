// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {PacketConsumer} from "../../src/PacketConsumer.sol";

contract MockPacketConsumer is PacketConsumer {
    constructor(
        address tunnelRouter_
    ) PacketConsumer(tunnelRouter_) {}

    function setPrice(bytes32 data, uint64 price, int64 timestamp) external {
        _prices[data] = Price({price: price, timestamp: timestamp});
    }
}
