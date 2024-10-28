// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/libraries/StringAddress.sol";
import "../src/PacketConsumer.sol";

contract StringAddressTest is Test {
    using StringAddress for string;

    function testStringAddress() public pure {
        string[] memory addrs = new string[](4);
        addrs[0] = "0x6D9b8Ec0D5982f918210A05724E176e5F96fC391";
        addrs[1] = "0x6d9b8ec0d5982f918210a05724e176e5f96fc391";
        addrs[2] = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
        addrs[3] = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

        address[] memory expectedAddrs = new address[](4);
        expectedAddrs[0] = 0x6D9b8Ec0D5982f918210A05724E176e5F96fC391;
        expectedAddrs[1] = 0x6D9b8Ec0D5982f918210A05724E176e5F96fC391;
        expectedAddrs[2] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        expectedAddrs[3] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(expectedAddrs[i], addrs[i].toAddress());
        }
    }

    function testStringRevertIncorrectLength() public {
        string memory test = "0x6D9b8Ec0D5982f918210A05724E17";
        vm.expectRevert(StringAddress.InvalidInput.selector);
        test.toAddress();
    }

    function testStringRevertInvalidCharacter() public {
        string memory test = "0x6D9b8Ec0D5982f91Z210A05724E176e5F96fC391"; // contain 'Z'
        vm.expectRevert("StringAddress: !char");
        test.toAddress();
    }
}
