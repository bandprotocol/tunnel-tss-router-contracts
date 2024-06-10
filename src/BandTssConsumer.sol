// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BandTssBridge.sol";
import "./FeedConsumer.sol";
import "./OracleConsumer.sol";

contract BandTssConsumer is BandTssBridge, FeedConsumer, OracleConsumer {
    constructor(uint8 _parity, uint256 _px) BandTssBridge(_parity, _px) {}
}
