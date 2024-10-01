// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IBandReserve {
    /// @dev Allow the whitelisted users to borrow some amount of token on behalf of the debtor.
    function borrowOnBehalf(uint amount, address debtor) external;

    /// @dev repay the debt on behalf of the debtor.
    function repay(address debtor) external payable;

    /// @dev return the debt amount.
    function debt(address debtor) external view returns (uint);
}
