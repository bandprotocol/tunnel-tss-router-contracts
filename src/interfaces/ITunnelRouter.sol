// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./IVault.sol";

interface ITunnelRouter {
    // ========================================
    // Events
    // ========================================

    /**
     * @notice Emitted when the maximum gas used in the process is set.
     * @param maxAllowableCallbackGasLimit The maximum allowable gas to be used
     * when calling the target contract.
     */
    event SetMaxAllowableCallbackGasLimit(uint256 maxAllowableCallbackGasLimit);

    /**
     * @notice Emitted when the additional gas is set.
     * @param additionalGas The additional gas estimated for relaying the message;
     * does not include the gas cost for executing the target contract.
     */
    event SetAdditionalGas(uint256 additionalGas);

    /**
     * @notice Emitted after the message is relayed to the target contract
     * to indicate the result of the process.
     *
     * @param tunnelID The tunnel ID that the message is relayed.
     * @param targetAddr The target address that the message is relayed.
     * @param sequence The sequence of the message.
     * @param isReverted The flag indicating whether the message is reverted.
     */
    event ProcessMessage(
        uint64 indexed tunnelID,
        address indexed targetAddr,
        uint64 indexed sequence,
        bool isReverted
    );

    /**
     * @notice Emitted when the target address is activated.
     *
     * @param tunnelID The tunnel ID that the sender is activating.
     * @param targetAddr The target address that the sender is activating.
     * @param latestNonce The latest nonce of the sender.
     */
    event Activate(
        uint64 indexed tunnelID,
        address indexed targetAddr,
        uint64 latestNonce
    );

    /**
     * @notice Emitted when the target address is deactivated.
     *
     * @param tunnelID The tunnel ID that the sender is deactivating.
     * @param targetAddr The target address that the sender is deactivating.
     * @param latestNonce The latest nonce of the sender.
     */
    event Deactivate(
        uint64 indexed tunnelID,
        address indexed targetAddr,
        uint64 latestNonce
    );

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Revert the transaction if the target contract is inactive.
     *
     * @param targetAddr The target address that is inactive.
     */
    error Inactive(address targetAddr);

    /**
     * @notice Revert the transaction if the target contract is active.
     *
     * @param targetAddr The target address that is inactive.
     */
    error Active(address targetAddr);

    /**
     * @notice Revert the transaction if the sequence is incorrect.
     *
     * @param expected The expected sequence of the tunnel.
     * @param input The input sequence of the tunnel.
     */
    error InvalidSequence(uint64 expected, uint64 input);

    /**
     * @notice Revert the transaction if the chainID is incorrect.
     *
     * @param chainID The chainID of the tunnel.
     */
    error InvalidChain(string chainID);

    /**
     * @notice Revert the transaction if the message and its signature doesn't match.
     */
    error InvalidSignature();

    /**
     * @notice Revert the transaction if contract cannot send fee to the specific address.
     */
    error FailSendTokens(address addr);

    /**
     * @notice Revert the transaction if the balance is insufficient.
     *
     * @param tunnelID The tunnel ID that the sender is withdrawing tokens.
     * @param addr The account from which the sender is withdrawing tokens.
     */
    error InsufficientBalance(uint64 tunnelID, address addr);

    // ========================================
    // Functions
    // ========================================

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
     * @param parity is the y part of the current public key
     * @param timestamp is the creation timestamp of the current public key
     * @param randomAddr is the address form of the commitment R.
     * @param s is the integer part of the signature.
     * @param message is the message being used for updating public key.
     */
    function relay(
        uint8 parity,
        uint64 timestamp,
        address randomAddr,
        uint256 s,
        bytes calldata message
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
