// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "../libraries/PacketDecoder.sol";

interface IPacketConsumer {
    // ========================================
    // Events
    // ========================================

    /**
     * @notice Emitted when the signal price is updated.
     *
     * @param signalId The Id of the signal whose price is updated.
     * @param price The new price of the signal.
     * @param timestamp The timestamp of the updated prices.
     */
    event SignalPriceUpdated(bytes32 indexed signalId, uint64 price, int64 timestamp);

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Reverts if the caller is not the tunnelRouter contract.
     */
    error UnauthorizedTunnelRouter();

    // ========================================
    // Functions
    // ========================================

    /**
     * @dev Processes the relayed message.
     *
     * The relayed message must be evaluated from the tunnelRouter contract and
     * verified by the tssVerifier contract before forwarding to the target contract.
     *
     * @param data The decoded tss message that is relayed from the tunnelRouter contract.
     */
    function process(PacketDecoder.TssMessage memory data) external;

    /**
     * @dev Activates the tunnel and set the sequence on tunnelRouter contract.
     *
     * This function deposits tokens into the vault and sets the latest sequence on the
     * tunnelRouter contract if the current deposit in the vault contract exceeds a threshold.
     * The transaction is reverted if the threshold is not met.
     *
     * This function should be called by the contract owner.
     *
     * @param latestSeq The new sequence of the tunnel.
     */
    function activate(uint64 latestSeq) external payable;

    /**
     * @dev Deactivates the tunnel on tunnelRouter contract.
     *
     * This function should be called by the contract owner.
     */
    function deactivate() external;

    /**
     * @dev Deposits the native tokens into the vault on behalf of the given account and tunnelId.
     * The amount of tokens to be deposited is provided as msg.value in the transaction.
     *
     * The contract calls the vault to deposit the tokens.
     */
    function deposit() external payable;

    /**
     * @dev Withdraws the native tokens from the vault contract with specific amount.
     *
     * This function should be called by the contract owner.
     */
    function withdraw(uint256 amount) external;

    /**
     * @dev Withdraws all native tokens from the vault contract.
     *
     * This function should be called by the contract owner.
     */
    function withdrawAll() external;

    /**
     * @dev Returns The tunnelRouter contract address.
     */
    function tunnelRouter() external view returns (address);

    /**
     * @dev Returns The tunnelId of the contract address.
     */
    function tunnelId() external view returns (uint64);
}
