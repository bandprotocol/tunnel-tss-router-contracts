// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BandTssVerifier.sol";
import "../src/interfaces/IBandTssVerifier.sol";
import "../src/FeedsConsumer.sol";
import "../src/SECP256k1.sol";

contract FeedsConsumerTest is Test {
    BandTssVerifier bandTssVerifier;
    FeedsConsumer feedsConsumer;
    bytes32 constant HASH_ORIGINATOR_REPLACEMENT =
        0xB1E192CBEADD6C77C810644A56E1DD40CEF65DDF0CB9B67DD42CDF538D755DE2;

    struct Input {
        uint64 timestamp;
        uint64 signingID;
        bytes32 originator;
        address rAddress;
        uint256 s;
        FeedsConsumer.SignalPriceInfo[] signalPrices;
    }

    function setUp() public {
        bandTssVerifier = new BandTssVerifier(HASH_ORIGINATOR_REPLACEMENT);
        feedsConsumer = new FeedsConsumer(
            IBandTssVerifier(address(bandTssVerifier))
        );
        bandTssVerifier.addPubKeyByOwner(
            2,
            52551505504720240751042067870270254170339901460264528997229698051448949240000
        );
    }

    function test_relayFeedsPriceData() public {
        FeedsConsumer.SignalPriceInfo[]
            memory signalPriceInfos = new FeedsConsumer.SignalPriceInfo[](1);
        signalPriceInfos[0] = FeedsConsumer.SignalPriceInfo({
            signalID: 0x0000000000000000000000000063727970746F5F70726963652E657468757364,
            price: 3352170000000
        });
        Input memory input = Input({
            timestamp: 1721025843,
            signingID: 1,
            originator: 0xF24573F7A6CC0E7D7531CBE20683417381AD9D341CAF8C864BCD89C33B98D09F,
            rAddress: 0x5CEf90220932AC930D4E0dCefB99501626De112F,
            s: 0xF6B9FE30F76B8568106B349CD27B7389C53FC4E913E5E42AB68ECE1991EF4DBA,
            signalPrices: signalPriceInfos
        });

        feedsConsumer.relayFeedsPriceData(
            input.signingID,
            input.timestamp,
            input.originator,
            input.rAddress,
            input.s,
            input.signalPrices
        );

        (uint actualPrice, uint64 actualTimestamp) = feedsConsumer.prices(
            signalPriceInfos[0].signalID
        );
        assertEq(actualPrice, signalPriceInfos[0].price);
        assertEq(actualTimestamp, input.timestamp);
    }
}
