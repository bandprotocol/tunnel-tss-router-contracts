// SPDX-License-Identifier: MIT
// ref: https://gist.github.com/Y5Yash/721a5f5c3e392a6a28f47db1d3114501
// ref: https://github.com/ethereum/ercs/blob/master/ERCS/erc-55.md

pragma solidity ^0.8.23;

library Address {
    bytes16 private constant _LOWER = "0123456789abcdef";
    bytes16 private constant _CAPITAL = "0123456789ABCDEF";

    ///@dev convert address to checksum address string.
    function toChecksumString(address addr) internal pure returns (string memory) {
        // get the hash of the lowercase address
        bytes memory lowercaseAddr = ToLowercaseBytes(addr);
        bytes32 hashedAddr = keccak256(abi.encodePacked(lowercaseAddr));

        // store checksum address with '0x' prepended in this.
        bytes memory result = new bytes(42);
        result[0] = "0";
        result[1] = "x";

        uint160 addrValue = uint160(addr);
        uint160 hashValue = uint160(bytes20(hashedAddr));

        // checksum logic from EIP-55
        for (uint256 i = 41; i > 1; --i) {
            uint256 b = addrValue & 0xf;

            if (hashValue & 0xf > 7) {
                result[i] = _CAPITAL[b];
            } else {
                result[i] = _LOWER[b];
            }

            addrValue >>= 4;
            hashValue >>= 4;
        }

        return string(abi.encodePacked(result));
    }

    ///@dev get convert address bytes to lowercase char hex bytes (without '0x').
    function ToLowercaseBytes(address addr) internal pure returns (bytes memory) {
        bytes memory s = new bytes(40);

        uint160 x = uint160(addr);
        for (uint256 i = 0; i < 20; i++) {
            uint8 b = uint8(x) & 0xff;
            s[39 - 2 * i - 1] = _LOWER[b >> 4]; // higher index
            s[39 - 2 * i] = _LOWER[b & 0xf]; // lower index
            x >>= 8;
        }

        return s;
    }
}
