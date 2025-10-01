// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "../libraries/PacketDecoder.sol";

interface IPacketConsumer {
    // ========================================
    // Structs
    // ========================================

    // An object that contains the price of a signal ID.
    struct Price {
        uint64 price;
        int64 timestamp;
    }

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
    event SignalPriceUpdated(
        bytes32 indexed signalId,
        uint64 price,
        int64 timestamp
    );

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Reverts if the caller is not the tunnelRouter contract.
     */
    error UnauthorizedTunnelRouter();

    // Custom error for string length exceeding 32 bytes
    error StringInputExceedsBytes32(string input);

    // Custom error for signal Id input that is not available.
    error SignalIdNotAvailable(string signalId);

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
     * @param tunnelId The tunnel ID that the sender contract is activating.
     * @param latestSeq The new sequence of the tunnel.
     */
    function activate(uint64 tunnelId, uint64 latestSeq) external payable;

    /**
     * @dev Deactivates the tunnel on tunnelRouter contract.
     *
     * This function should be called by the contract owner.
     *
     * @param tunnelId The tunnel ID that the sender contract is deactivating.
     */
    function deactivate(uint64 tunnelId) external;

    /**
     * @dev Deposits the native tokens into the vault on behalf of the contract address and tunnelId.
     * The amount of tokens to be deposited is provided as msg.value in the transaction.
     *
     * The contract calls the vault to deposit the tokens.
     *
     * @param tunnelId The tunnel ID that the sender contract is depositing.
     */
    function deposit(uint64 tunnelId) external payable;

    /**
     * @dev Withdraws the native tokens from the vault contract with specific amount.
     *
     * This function should be called by the contract owner.
     *
     * @param tunnelId The tunnel ID that the sender contract is withdrawing.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(uint64 tunnelId, uint256 amount) external;

    /**
     * @dev Withdraws all native tokens from the vault contract.
     *
     * This function should be called by the contract owner.
     *
     * @param tunnelId The tunnel ID that the sender contract is withdrawing.
     */
    function withdrawAll(uint64 tunnelId) external;

    /**
     * @dev Returns The tunnelRouter contract address.
     */
    function tunnelRouter() external view returns (address);

    /**
     * @dev Returns the price for the given string of signal, reverting if it does not exist.
     *
     * @param _signalId The signal ID to retrieve the price for.
     */
    function getPrice(string calldata _signalId) external view returns (Price memory);

    /**
     * @dev Returns the prices for the given array of string of signal, reverting if any do not exist.
     *
     * @param _signalIds The list of signal IDs to retrieve prices for.
     */
    function getPriceBatch(string[] calldata _signalIds) external view returns (Price[] memory);
}
