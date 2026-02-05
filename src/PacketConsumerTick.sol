// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./PacketConsumerBase.sol";
import "./interfaces/IPacketConsumer.sol";
import "./libraries/PacketDecoder.sol";

contract PacketConsumerTick is PacketConsumerBase {

    mapping(uint256 => uint256) public refs;
    mapping(bytes32 => uint256) public symbolsToIDs;
    mapping(uint256 => bytes32) public idsToSymbols;

    uint256 public constant MID_TICK = 262144;

    uint256 public totalSymbolsCount = 0;

    constructor(address tunnelRouter_) PacketConsumerBase(tunnelRouter_) {}

    /**
     * @dev Converts a right-aligned bytes32 value back to string
     */
    function rightAlignedBytes32ToString(bytes32 b) public pure returns (string memory) {
        // Find the index of the first non-zero byte (strip leading zero padding)
        uint8 start = 0;
        while (start < 32 && b[start] == 0) {
            start++;
        }
        // If all bytes are zero, return empty string
        if (start == 32) {
            return "";
        }
        uint8 len = 32 - start;
        bytes memory out = new bytes(len);
        for (uint8 i = 0; i < len; i++) {
            out[i] = b[start + i];
        }
        
        return string(out);
    }

    /**
     * @dev See {IPacketConsumer-getPrice}.
     */
    function getPrice(string calldata _signalId) external view returns (Price memory) {
        (uint256 tick, uint256 timestamp) = getTickAndTime(stringToRightAlignedBytes32(_signalId));
        uint256 rate = _getPriceFromTick(tick);

        Price memory price = Price({
            price: uint64(rate),
            timestamp: int64(uint64(timestamp))
        });

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
            (uint256 tick, uint256 timestamp) = getTickAndTime(stringToRightAlignedBytes32(_signalIds[i]));
            uint256 rate = _getPriceFromTick(tick);

            Price memory price = Price({
                price: uint64(rate),
                timestamp: int64(uint64(timestamp))
            });

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
        unchecked {
            PacketDecoder.Packet memory packet = data.packet;

            if (packet.timestamp < int64((1 << 18) - 1)) revert InvalidPacketTimestamp();
            if (data.encoderType != PacketDecoder.EncoderType.Tick) revert InvalidEncoderType();

            uint256 time = uint256(int256(packet.timestamp));
        
            uint256 id;
            uint256 sid = type(uint256).max;
            uint256 nextSID;
            uint256 sTime;
            uint256 sVal;
            uint256 shiftLen;

            uint256 newTimeSlot = time - (1 << 18) + 1;
            uint256 idMinusOne;

            uint256 signalsLength = packet.signals.length;

            for (uint256 i = 0; i < signalsLength; ++i) {
                id = symbolsToIDs[packet.signals[i].signal];
                if (id == 0) revert SignalIdNotAvailable(rightAlignedBytes32ToString(packet.signals[i].signal));
                idMinusOne = id - 1;

                nextSID = idMinusOne / 6;
                if (sid != nextSID) {
                    if (sVal != 0) refs[sid] = sVal;

                    sVal = refs[nextSID];
                    sid = nextSID;
                    sTime = _extractSlotTime(sVal);
                    if (newTimeSlot > sTime) {
                        sTime = newTimeSlot;
                        sVal = _rebaseTime(sVal, sTime);
                    }
                }

                shiftLen = 204 - (37 * (idMinusOne % 6));
                sVal = (sTime + _extractTimeOffset(sVal, shiftLen) < time) 
                    ? _setTicksAndTimeOffset(sVal, time - sTime, packet.signals[i].price, shiftLen - 19) 
                    : sVal;
            }

            if (sVal != 0) refs[sid] = sVal;
        }
    }

    function _extractSlotTime(uint256 val) private pure returns (uint256 t) {
        unchecked {
            t = (val >> 225) & ((1 << 31) - 1);
        }
    }

    function _extractSize(uint256 val) private pure returns (uint256 s) {
        unchecked {
            s = (val >> 222) & ((1 << 3) - 1);
        }
    }

    function _extractTick(uint256 val, uint256 shiftLen) private pure returns (uint256 tick) {
        unchecked {
            tick = (val >> shiftLen) & ((1 << 19) - 1);
        }
    }

    function _extractTimeOffset(uint256 val, uint256 shiftLen) private pure returns (uint256 offset) {
        unchecked {
            offset = (val >> shiftLen) & ((1 << 18) - 1);
        }
    }

    function _setTime(uint256 val, uint256 time) private pure returns (uint256 newVal) {
        unchecked {
            newVal = (val & (type(uint256).max >> 31)) | (time << 225);
        }
    }

    function _setSize(uint256 val, uint256 size) private pure returns (uint256 newVal) {
        unchecked {
            newVal = (val & ((type(uint256).max << (37 * (6 - size))) - ((((1 << 3) - 1)) << 222))) | (size << 222);
        }
    }

    function _setTimeOffset(uint256 val, uint256 timeOffset, uint256 shiftLen) private pure returns (uint256 newVal) {
        unchecked {
            newVal = ((val & ~(uint256((1 << 18) - 1) << (shiftLen + 19))) | (timeOffset << (shiftLen + 19)));
        }
    }

    function _setTicksAndTimeOffset(uint256 val, uint256 timeOffset, uint256 tick, uint256 shiftLen)
        private
        pure
        returns (uint256 newVal)
    {
        unchecked {
            newVal = (val & (~(uint256((1 << 37) - 1) << shiftLen)))
                | (((timeOffset << 19) | (tick & ((1 << 19) - 1))) << shiftLen);
        }
    }

    function _rebaseTime(uint256 val, uint256 time) private pure returns (uint256 newVal) {
        unchecked {
            uint256 sTime = _extractSlotTime(val);
            uint256 sSize = _extractSize(val);
            uint256 shiftLen;
            for (uint256 i = 0; i < sSize; i++) {
                shiftLen = 204 - (37 * i);
                uint256 timeOffset = _extractTimeOffset(val, shiftLen);
                val = (sTime + timeOffset < time) 
                    // Reset tick and offset to zero for expired data to clear obsolete entries
                    ? _setTicksAndTimeOffset(val, 0, 0, shiftLen - 19) 
                    : _setTimeOffset(val, sTime + timeOffset - time, shiftLen - 19);
            }
            newVal = _setTime(val, time);
        }
    }

    function _getTickAndTime(uint256 slot, uint8 idx) private view returns (uint256 tick, uint256 lastUpdated) {
        unchecked {
            uint256 sVal = refs[slot];
            uint256 idx_x_37 = idx * 37;
            return
                (_extractTick(sVal, 185 - idx_x_37), _extractTimeOffset(sVal, 204 - idx_x_37) + _extractSlotTime(sVal));
        }
    }

    function getSlotAndIndex(bytes32 symbol) public view returns (uint256 slot, uint8 idx) {
        unchecked {
            uint256 id = symbolsToIDs[symbol];
            if (id == 0) revert SignalIdNotAvailable(rightAlignedBytes32ToString(symbol));
            return ((id - 1) / 6, uint8((id - 1) % 6));
        }
    }

    function getTickAndTime(bytes32 symbol) public view returns (uint256 tick, uint256 lastUpdated) {
        unchecked {
            (uint256 slot, uint8 idx) = getSlotAndIndex(symbol);
            (tick, lastUpdated) = _getTickAndTime(slot, idx);
        }
    }

    function _getPriceFromTick(uint256 x) private pure returns (uint256 y) {
        unchecked {
            if (x == 0) return 0;
            y = 649037107316853453566312041152512;
            if (x < MID_TICK) {
                x = MID_TICK - x;
                if (x & 0x01 != 0) y = (y * 649102011027585138911668672356627) >> 109;
                if (x & 0x02 != 0) y = (y * 649166921228687897425559839223862) >> 109;
                if (x & 0x04 != 0) y = (y * 649296761104602847291923925447306) >> 109;
                if (x & 0x08 != 0) y = (y * 649556518769447606681106054382372) >> 109;
                if (x & 0x10 != 0) y = (y * 650076345896668132522271100656030) >> 109;
                if (x & 0x20 != 0) y = (y * 651117248505878973533694452870408) >> 109;
                if (x & 0x40 != 0) y = (y * 653204056474534657407624669811404) >> 109;
                if (x & 0x80 != 0) y = (y * 657397758286396885483233885325217) >> 109;
                if (x & 0x0100 != 0) y = (y * 665866108005128170549362417755489) >> 109;
                if (x & 0x0200 != 0) y = (y * 683131470899774684431604377857106) >> 109;
                if (x & 0x0400 != 0) y = (y * 719016834742958293196733842540130) >> 109;
                if (x & 0x0800 != 0) y = (y * 796541835305874991615834691778664) >> 109;
                if (x & 0x1000 != 0) y = (y * 977569522974447437629335387266319) >> 109;
                if (x & 0x2000 != 0) y = (y * 1472399900522103311842374358851872) >> 109;
                if (x & 0x4000 != 0) y = (y * 3340273526146976564083509455290620) >> 109;
                if (x & 0x8000 != 0) y = (y * 17190738562859105750521122099339319) >> 109;
                if (x & 0x010000 != 0) y = (y * 455322953040804340936374685561109626) >> 109;
                if (x & 0x020000 != 0) y = (y * 319425483117388922324853186559947171877) >> 109;
                y = 649037107316853453566312041152512000000000 / y;
            } else {
                x = x - MID_TICK;
                if (x & 0x01 != 0) y = (y * 649102011027585138911668672356627) >> 109;
                if (x & 0x02 != 0) y = (y * 649166921228687897425559839223862) >> 109;
                if (x & 0x04 != 0) y = (y * 649296761104602847291923925447306) >> 109;
                if (x & 0x08 != 0) y = (y * 649556518769447606681106054382372) >> 109;
                if (x & 0x10 != 0) y = (y * 650076345896668132522271100656030) >> 109;
                if (x & 0x20 != 0) y = (y * 651117248505878973533694452870408) >> 109;
                if (x & 0x40 != 0) y = (y * 653204056474534657407624669811404) >> 109;
                if (x & 0x80 != 0) y = (y * 657397758286396885483233885325217) >> 109;
                if (x & 0x0100 != 0) y = (y * 665866108005128170549362417755489) >> 109;
                if (x & 0x0200 != 0) y = (y * 683131470899774684431604377857106) >> 109;
                if (x & 0x0400 != 0) y = (y * 719016834742958293196733842540130) >> 109;
                if (x & 0x0800 != 0) y = (y * 796541835305874991615834691778664) >> 109;
                if (x & 0x1000 != 0) y = (y * 977569522974447437629335387266319) >> 109;
                if (x & 0x2000 != 0) y = (y * 1472399900522103311842374358851872) >> 109;
                if (x & 0x4000 != 0) y = (y * 3340273526146976564083509455290620) >> 109;
                if (x & 0x8000 != 0) y = (y * 17190738562859105750521122099339319) >> 109;
                if (x & 0x010000 != 0) y = (y * 455322953040804340936374685561109626) >> 109;
                if (x & 0x020000 != 0) y = (y * 319425483117388922324853186559947171877) >> 109;
                y = (y * 1e9) / 649037107316853453566312041152512;
            }
        }
    }

    function getPriceFromTick(uint256 x) public pure returns (uint256 y) {
        y = _getPriceFromTick(x);
    }

    function listing(string[] calldata symbols) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (symbols.length == 0) return;

        uint256 _totalSymbolsCount = totalSymbolsCount;
        uint256 sid = _totalSymbolsCount / 6;
        uint256 sVal = refs[sid];
        uint256 sSize = _extractSize(sVal);

        for (uint256 i = 0; i < symbols.length; i++) {
            bytes32 symbolBytes32 = stringToRightAlignedBytes32(symbols[i]);
            require(symbolsToIDs[symbolBytes32] == 0, "listing: FAIL_SYMBOL_IS_ALREADY_SET");

            uint256 slotID = _totalSymbolsCount / 6;

            _totalSymbolsCount++;
            symbolsToIDs[symbolBytes32] = _totalSymbolsCount;
            idsToSymbols[_totalSymbolsCount] = symbolBytes32;

            if (sid != slotID) {
                refs[sid] = sVal;

                sid = slotID;
                sVal = refs[sid];
                sSize = _extractSize(sVal);
            }

            sSize++;
            sVal = _setSize(sVal, sSize);
        }

        refs[sid] = sVal;
        totalSymbolsCount = _totalSymbolsCount;
    }

    function delisting(string[] calldata symbols) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _totalSymbolsCount = totalSymbolsCount;
        uint256 slotID1;
        uint256 slotID2;
        uint256 sVal1;
        uint256 sVal2;
        uint256 sSize;
        uint256 shiftLen;
        uint256 lastSegment;
        uint256 time;
        bytes32 lastSymbol;
        for (uint256 i = 0; i < symbols.length; i++) {
            bytes32 symbolBytes32 = stringToRightAlignedBytes32(symbols[i]);
            uint256 id = symbolsToIDs[symbolBytes32];
            require(id != 0, "delisting: FAIL_SYMBOL_NOT_AVAILABLE");

            lastSymbol = idsToSymbols[_totalSymbolsCount];

            symbolsToIDs[lastSymbol] = id;
            idsToSymbols[id] = lastSymbol;

            slotID1 = (_totalSymbolsCount - 1) / 6;
            slotID2 = (id - 1) / 6;
            sVal1 = refs[slotID1];
            sSize = _extractSize(sVal1);
            lastSegment = (sVal1 >> (37 * (6 - sSize))) & ((1 << 37) - 1);
            shiftLen = 37 * (5 - ((id - 1) % 6));

            if (slotID1 == slotID2) {
                sVal1 = (sVal1 & (type(uint256).max - (((1 << 37) - 1) << shiftLen))) | (lastSegment << shiftLen);
            } else {
                sVal2 = refs[slotID2];

                time = _extractSlotTime(sVal1) + (lastSegment >> 19);
                require(time >= _extractSlotTime(sVal2), "delisting: FAIL_LAST_TIMESTAMP_IS_LESS_THAN_TARGET_TIMESTAMP");
                time -= _extractSlotTime(sVal2);
                require(time < 1 << 18, "delisting: FAIL_DELTA_TIME_EXCEED_3_DAYS");
                lastSegment = (time << 19) | (lastSegment & ((1 << 19) - 1));

                refs[slotID2] =
                    (sVal2 & (type(uint256).max - (((1 << 37) - 1) << shiftLen))) | (lastSegment << shiftLen);
            }

            refs[slotID1] = _setSize(sVal1, sSize - 1);

            delete symbolsToIDs[symbolBytes32];
            delete idsToSymbols[_totalSymbolsCount];

            _totalSymbolsCount--;
        }

        totalSymbolsCount = _totalSymbolsCount;
    }
}
