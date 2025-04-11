// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/libraries/Originator.sol";

contract OriginatorTest is Test {
    function testOriginatorHash() public pure {
        bytes32 hashed = Originator.hash(
            0x0e1ac2c4a50a82aa49717691fc1ae2e5fa68eff45bd8576b0f2be7a0850fa7c6,
            1,
            0x5af6d81c929088b10c1f0eec52fd2ce69844fa9be1d417a4d7bda2928581dbd2,
            address(0xE8EC2D7FE265c6e5c1850D43f1b1d2D03567E216)
        );
        bytes32 expected = 0x93bad859185ea4e3b9b26177a7f5c0418dd563cda782f892af695fc7d1f52818;
        assertEq(hashed, expected);
    }
}
