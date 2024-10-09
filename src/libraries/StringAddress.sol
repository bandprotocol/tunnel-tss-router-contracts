// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

library StringAddress {
    /**
     * @dev Convert a string to an address.
     *
     * The string must be 42 characters long and only contain valid hexadecimal characters.
     *
     * @param str The string to convert.
     * @return The converted address.
     */
    function toAddress(string memory str) internal pure returns (address) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length == 42, "StringAddress: !length");
        uint160 result;

        assembly {
            for {
                let i := 2
            } lt(i, 42) {
                i := add(i, 1)
            } {
                let char := byte(0, mload(add(str, add(0x20, i))))
                let converted := false

                // Check if character is a digit (0-9)
                if and(gt(char, 0x2f), lt(char, 0x3a)) {
                    result := add(shl(4, result), sub(char, 0x30)) // '0' -> 0
                    converted := true
                }

                // Check if character is a lowercase letter (a-f)
                if and(gt(char, 0x60), lt(char, 0x67)) {
                    result := add(shl(4, result), add(sub(char, 0x61), 10)) // 'a' -> 10
                    converted := true
                }

                // Check if character is an uppercase letter (A-F)
                if and(gt(char, 0x40), lt(char, 0x47)) {
                    result := add(shl(4, result), add(sub(char, 0x41), 10)) // 'A' -> 10
                    converted := true
                }

                if eq(converted, false) {
                    let revertData := mload(0x40) // Load the free memory pointer
                    mstore(revertData, shl(229, 0x00461bcd)) // Selector for method Error(string)
                    mstore(add(revertData, 0x04), 0x20) // string offset; padded to 32 bytes
                    mstore(add(revertData, 0x24), 20) // error msg length;
                    mstore(add(revertData, 0x44), "StringAddress: !char") // Store the actual error message

                    revert(revertData, 0x64)
                }
            }
        }

        return address(result);
    }
}
