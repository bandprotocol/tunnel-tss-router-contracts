// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "../libraries/PacketDecoder.sol";

interface IDataConsumer {
    /**
     * @dev Deposit the native tokens into the vault on behalf of the given account and tunnelID.
     * The amount of tokens to be deposited is provided as msg.value in the transaction.
     *
     * The contract calls the tunnelRouter to deposit the tokens in vault contract.
     */
    function deposit() external payable;

    // ========================================
    // Events
    // ========================================

    /**
     * @notice Emitted when the signal price is updated.
     *
     * @param signalID The signal ID that the price is updated.
     * @param price The new price of the signal.
     * @param timestamp The timestamp of the update prices.
     */
    event UpdateSignalPrice(
        bytes32 indexed signalID,
        uint64 price,
        int64 timestamp
    );

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice The caller is not the tunnelRouter contract.
     */
    error OnlyTunnelRouter();

    /**
     * @notice The hashOriginator is not matched.
     */
    error InvalidHashOriginator();

    /**
     * @notice Revert the transaction if contract cannot send fee to the specific address.
     */
    error FailSendTokens(address addr);

    // ========================================
    // Functions
    // ========================================

    /**
     * @dev Process the relayed message.
     *
     * The relayed message should be evaluated from the tunnelRouter contract and
     * should be verified from the tssVerifier contract before forwarding to the contract.
     *
     * @param data The decoded tss message that is relayed from the tunnelRouter contract.
     */
    function process(PacketDecoder.TssMessage memory data) external;

    /**
     * @dev The tunnelRouter contract address.
     */
    function tunnelRouter() external view returns (address);

    /**
     * @dev Activate the tunnel and set the sequence on tunnelRouter contract.
     *
     *
     * This also deposit tokens into the vault and set the latest sequence on the
     * tunnelRouter contract if the current deposit in the vault contract is over a threshold;
     * otherwise, the transaction is reverted.
     *
     * This function should be called by the owner of the contract only.
     *
     * @param latestSeq The new sequence of the tunnel.
     */
    function activate(uint64 latestSeq) external payable;

    /**
     * @dev Deactivate the tunnel on tunnelRouter contract.
     *
     * This also withdraws the tokens from the vault contract if there is existing deposit
     * in the contract.
     */
    function deactivate() external;
}
