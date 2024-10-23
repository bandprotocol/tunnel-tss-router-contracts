// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IVault {
    /**
     * @dev Deposit the native tokens into the vault on behalf of the given account and tunnelID.
     * The amount of tokens to be deposited is provided as msg.value in the transaction.
     *
     * @param tunnelID The ID of the tunnel into which the sender is depositing tokens.
     * @param account The account into which the sender is depositing tokens.
     */
    function deposit(uint64 tunnelID, address account) external payable;

    /**
     * @dev withdraws native tokens from the sender's account associated with the given tunnelID.
     *
     * Sender cannot withdraw the tokens if the balance is less than the threshold.
     *
     * @param tunnelID the ID of the tunnel from which the sender is withdrawing tokens.
     * @param amount the amount of tokens to withdraw.
     */
    function withdraw(uint64 tunnelID, uint256 amount) external;

    /**
     * @dev withdraws all native tokens from the given account associated with the given tunnelID
     * and send to the account address.
     *
     * Sender should be the tunnelRouter contract.
     *
     * @param tunnelID the ID of the tunnel from which the sender is withdrawing tokens.
     * @param account the account from which the sender withdraw tokens.
     */
    function withdrawAll(uint64 tunnelID, address account) external;

    /**
     * @dev collect the fee from the account and the given tunnelID.
     *
     * This function should be called by the tunnelRouter contract only.
     *
     * @param tunnelID the ID of the tunnel from which the caller is withdrawing tokens.
     * @param account The account from which the caller is withdrawing tokens.
     * @param amount the amount of tokens to withdraw.
     */
    function collectFee(
        uint64 tunnelID,
        address account,
        uint256 amount
    ) external;

    /**
     * @dev checks the balance of the account associated with the given tunnelID is over a threshold.
     */
    function isBalanceOverThreshold(
        uint64 tunnelID,
        address account
    ) external view returns (bool);

    /**
     * @dev Returns the tunnel router contract address.
     */
    function tunnelRouter() external view returns (address);
}
