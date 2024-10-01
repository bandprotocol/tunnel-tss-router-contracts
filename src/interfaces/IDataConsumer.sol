// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IDataConsumer {
    /// @dev allow the tunnel router to send a new message for processing.
    function process(bytes calldata message) external;

    /// @dev allow the tunnel router to collect fee from the target contract.
    function collectFee(uint amount) external;

    /// @dev return the address of the tunnel router.
    function tunnelRouter() external view returns (address);
}
