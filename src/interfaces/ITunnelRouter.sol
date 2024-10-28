// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./IVault.sol";

interface ITunnelRouter {
    /**
     * @dev relay the message to the target contract.
     *
     * The contract verify the message's sequence and the signature before forwarding to
     * the dataConsumer contract.
     *
     * The sender is entitled to a reward from the vault contract, even if the dataConsumer
     * contract fails to process the message. The reward is calculated based on the gas
     * consumed when calling dataConsumer to process the message, plus an predefined amount of
     * additional estimated gas used by the others in the relaying process.
     *
     * @param message is the message to be relayed.
     * @param rAddr is the random address of the signature.
     * @param signature is the signature of the message.
     */
    function relay(
        bytes calldata message,
        address rAddr,
        uint256 signature
    ) external;

    /**
     * @dev activate the sender and associated tunnelID.
     *
     * This also deposit into the vault and set the latest sequence if the existing deposit
     * is above the threshold.
     *
     * @param tunnelID is the tunnelID that the sender contract is activating.
     * @param latestSeq is the new sequence of the tunnelID.
     */
    function activate(uint64 tunnelID, uint64 latestSeq) external payable;

    /**
     * @dev deactivate the pair of the sender address and the tunnelID.
     *
     * This also withdraws the tokens from the vault contract if there is an existing deposit.
     *
     * @param tunnelID is the tunnelID that the sender contract is deactivating.
     */
    function deactivate(uint64 tunnelID) external;

    /**
     * @dev Deposit the native tokens into the vault on behalf of the given account and tunnelID.
     * The amount of tokens to be deposited is provided as msg.value in the transaction.
     *
     * The contract calls the vault contract to deposit the tokens.
     *
     * @param tunnelID The ID of the tunnel into which the sender is depositing tokens.
     * @param account The account into which the sender is depositing tokens.
     */
    function deposit(uint64 tunnelID, address account) external payable;

    /**
     * @dev Returns the vault contract address.
     */
    function vault() external view returns (IVault);
}
