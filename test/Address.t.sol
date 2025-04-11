// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/libraries/Address.sol";
import "../src/PacketConsumer.sol";

contract AddressTest is Test {
    function testChecksumAddressString() public pure {
        address[] memory addrs = new address[](4);
        addrs[0] = 0x6D9b8Ec0D5982f918210A05724E176e5F96fC391;
        addrs[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        addrs[2] = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5;
        addrs[3] = 0xc25a272A4D2Ef4c80173187Bf69f4238c5b6564f;

        string[] memory expectedStrs = new string[](4);
        expectedStrs[0] = "0x6D9b8Ec0D5982f918210A05724E176e5F96fC391";
        expectedStrs[1] = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
        expectedStrs[2] = "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5";
        expectedStrs[3] = "0xc25a272A4D2Ef4c80173187Bf69f4238c5b6564f";

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(expectedStrs[i], Address.toChecksumString(addrs[i]));
        }
    }

    function testLowerCaseBytes() public pure {
        address[] memory addrs = new address[](4);
        addrs[0] = 0x6D9b8Ec0D5982f918210A05724E176e5F96fC391;
        addrs[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        addrs[2] = 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5;
        addrs[3] = 0xc25a272A4D2Ef4c80173187Bf69f4238c5b6564f;

        string[] memory expectedStrs = new string[](4);
        expectedStrs[0] = "6d9b8ec0d5982f918210a05724e176e5f96fc391";
        expectedStrs[1] = "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
        expectedStrs[2] = "95222290dd7278aa3ddd389cc1e1d165cc4bafe5";
        expectedStrs[3] = "c25a272a4d2ef4c80173187bf69f4238c5b6564f";

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(expectedStrs[i], string(Address.ToLowercaseBytes(addrs[i])));
        }
    }
}
