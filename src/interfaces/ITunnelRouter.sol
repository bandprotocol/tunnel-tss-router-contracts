// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./IVault.sol";

interface ITunnelRouter {
    // ========================================
    // Events
    // ========================================

    /**
     * @notice Emitted when the callback gas limit is set.
     *
     * @param callbackGasLimit The maximum gas limit can be used when calling the target contract.
     */
    event CallbackGasLimitSet(uint256 callbackGasLimit);

    /**
     * @notice Emitted when the additional gas used is set.
     *
     * @param additionalGasUsed The additional gas estimated for relaying the message;
     * does not include the gas cost for executing the target contract.
     */
    event AdditionalGasUsedSet(uint256 additionalGasUsed);

    /**
     * @notice Emitted after the message is relayed to the target contract
     * to indicate the result of the process.
     *
     * @param originatorHash The originatorHash of the target that the sender is deactivating.
     * @param sequence The sequence of the message.
     * @param isReverted The flag indicating whether the message is reverted.
     */
    event MessageProcessed(bytes32 indexed originatorHash, uint64 indexed sequence, bool isReverted);

    /**
     * @notice Emitted when the target address is activated.
     *
     * @param originatorHash The originatorHash of the target that the sender is deactivating.
     * @param latestNonce The latest nonce of the sender.
     */
    event Activated(bytes32 indexed originatorHash, uint64 latestNonce);

    /**
     * @notice Emitted when the target address is deactivated.
     *
     * @param originatorHash The originatorHash of the target that the sender is deactivating.
     * @param latestNonce The latest nonce of the sender.
     */
    event Deactivated(bytes32 indexed originatorHash, uint64 latestNonce);

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Reverts if the target contract is inactive.
     *
     * @param targetAddr The target address that is inactive.
     */
    error InactiveTunnel(address targetAddr);

    /**
     * @notice Reverts if the target contract is already active.
     *
     * @param targetAddr The target address that is active.
     */
    error ActiveTunnel(address targetAddr);

    /**
     * @notice Reverts if the encoder type is undefined.
     */
    error UndefinedEncoderType();

    /**
     * @notice Reverts if the sequence is incorrect.
     *
     * @param expected The expected sequence of the tunnel.
     * @param input The input sequence of the tunnel.
     */
    error InvalidSequence(uint64 expected, uint64 input);

    /**
     * @notice Reverts if the chain ID is incorrect.
     *
     * @param chainId The chain ID of the tunnel.
     */
    error InvalidChain(string chainId);

    /**
     * @notice Reverts if the message and its signature doesn't match.
     */
    error InvalidSignature();

    /**
     * @notice Reverts if the contract cannot send fee to the specific address.
     */
    error TokenTransferFailed(address addr);

    /**
     * @notice Reverts if the remaining balance is insufficient to withdraw.
     *
     * @param tunnelId The tunnel ID that the sender is withdrawing tokens.
     * @param addr The account from which the sender is withdrawing tokens.
     */
    error InsufficientRemainingBalance(uint64 tunnelId, address addr);

    // ========================================
    // Functions
    // ========================================

    ///@dev Tunnel information
    struct TunnelInfo {
        bool isActive; // whether the tunnel is active or not
        uint64 latestSequence; // the latest sequence of the tunnel
        uint256 balance; // the remaining balance of the tunnel
    }

    /**
     * @dev Relays the message to the target contract.
     *
     * Verifies the message's sequence and signature before forwarding it to
     * the data consumer contract. The sender is entitled to a reward from the
     * vault contract, even if the data consumer contract fails to process the
     * message. The reward is based on the gas consumed during processing plus
     * a predefined additional gas estimate.
     *
     * @param message The message to be relayed.
     * @param randomAddr The random address used in signature.
     * @param signature The signature of the message.
     */
    function relay(bytes calldata message, address randomAddr, uint256 signature) external;

    /**
     * @dev Activates the sender and associated tunnel ID.
     *
     * @param tunnelId The tunnel ID that the sender contract is activating.
     * @param latestSeq The new sequence of the tunnelID.
     */
    function activate(uint64 tunnelId, uint64 latestSeq) external payable;

    /**
     * @dev Deactivates the sender and associated tunnel ID.
     *
     * @param tunnelId The tunnel ID being deactivated.
     */
    function deactivate(uint64 tunnelId) external;

    /**
     * @dev Returns the minimum balance required to keep the tunnel active.
     *
     * @return uint256 The minimum balance threshold.
     */
    function minimumBalanceThreshold() external view returns (uint256);

    /**
     * @dev Returns the tunnel information.
     *
     * @param tunnelId The ID of the tunnel.
     * @param addr The target contract address.
     *
     * @return bool True if the tunnel is active, false otherwise.
     */
    function tunnelInfo(uint64 tunnelId, address addr) external view returns (TunnelInfo memory);

    /**
     * @dev Returns the active status of the target contract.
     *
     * @param originatorHash The originatorHash of the target contract.
     *
     * @return bool True if the target contract is active, false otherwise.
     */
    function isActive(bytes32 originatorHash) external view returns (bool);

    /**
     * @dev Returns the sequence of the target contract.
     *
     * @param originatorHash The originatorHash of the target contract.
     *
     * @return uint64 The sequence of the target contract.
     */
    function sequence(bytes32 originatorHash) external view returns (uint64);

    /**
     * @dev Returns the vault contract address.
     */
    function vault() external view returns (IVault);
}
