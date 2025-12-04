// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./IVault.sol";

interface ITunnelRouter {
    // ========================================
    // Structs
    // ========================================

    /**
     * @dev Stores the core details of a tunnel, mapped by its originator hash.
     * @param isActive A flag indicating if the tunnel is currently active
     * @param sequence The current message sequence number for the tunnel
     * @param tunnelId The unique identifier for the tunnel
     * @param targetAddr The address of the target consumer contract for this tunnel.
     */
    struct TunnelDetail {
        bool isActive;
        uint64 sequence;
        uint64 tunnelId;
        address targetAddr;
    }

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
     * @notice Emitted when the tssVerifier is set.
     *
     * @param tssVerifier The address of TssVerifier contract.
     */
    event TssVerifierSet(address tssVerifier );

    /**
     * @notice Emitted after the message is relayed to the target contract
     * to indicate the result of the process.
     *
     * @param originatorHash The originatorHash of the target that the sender is deactivating.
     * @param sequence The sequence of the message.
     * @param isSuccess The flag indicating whether the message is successful execute.
     */
    event MessageProcessed(
        bytes32 indexed originatorHash,
        uint64 indexed sequence,
        bool isSuccess
    );

    /**
     * @notice Emitted when the target is activated.
     *
     * @param originatorHash The originatorHash of the target that the sender is activating.
     * @param latestSequence The latest sequence of the tunnel.
     */
    event Activated(bytes32 indexed originatorHash, uint64 latestSequence);

    /**
     * @notice Emitted when the target is deactivated.
     *
     * @param originatorHash The originatorHash of the target that the sender is deactivating.
     * @param latestSequence The latest sequence of the tunnel.
     */
    event Deactivated(bytes32 indexed originatorHash, uint64 latestSequence);

    /**
     * @notice Emitted when a sender's address is added to or removed from the whitelist.
     *
     * @param sender The address of the sender whose whitelist status is being updated.
     * @param flag A boolean value indicating the whitelist status of the address:
     * `true` if the address is added to the whitelist, `false` if removed.
     */
    event SetWhitelist(address indexed sender, bool flag);

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice Reverts if the target contract is inactive.
     *
     * @param originatorHash The originatorHash of the target contract and tunnelID.
     */
    error TunnelNotActive(bytes32 originatorHash);

    /**
     * @notice Reverts if the target contract is already active.
     *
     * @param originatorHash The originatorHash of the target contract and tunnelID.
     */
    error TunnelAlreadyActive(bytes32 originatorHash);

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
     * @notice Reverts if the message and its signature doesn't match.
     */
    error InvalidSignature();

    /**
     * @notice Reverts if the remaining balance is insufficient to withdraw.
     *
     * @param tunnelId The tunnel ID that the sender is withdrawing tokens.
     * @param addr The account from which the sender is withdrawing tokens.
     */
    error InsufficientRemainingBalance(uint64 tunnelId, address addr);

    /**
     * @notice Reverts if the sender is not whitelisted.
     */
    error SenderNotWhitelisted(address addr);

    /**
     * @notice Reverts if the sender is address(0).
     */
    error InvalidSenderAddress();

    // ========================================
    // Functions
    // ========================================

    ///@dev Tunnel information
    struct TunnelInfo {
        bool isActive; // whether the tunnel is active or not
        uint64 latestSequence; // the latest sequence of the tunnel
        uint256 balance; // the remaining balance of the tunnel
        bytes32 originatorHash; // the originator hash of the tunnel
    }

    /**
     * @dev Relays the message to the target contract.
     *
     * Verifies the message's sequence and signature before forwarding it to
     * the packet consumer contract. The sender is entitled to a reward from the
     * vault contract, even if the packet consumer contract fails to process the
     * message. The reward is based on the gas consumed during processing plus
     * a predefined additional gas estimate.
     *
     * @param message The message to be relayed.
     * @param randomAddr The random address used in signature.
     * @param signature The signature of the message.
     */
    function relay(
        bytes calldata message,
        address randomAddr,
        uint256 signature
    ) external;

    /**
     * @dev Activates the sender and associated tunnel ID.
     *
     * This function should be called by the consumer contract as we use msg.sender in constructing
     * the originatorHash.
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
     * @return TunnelInfo The tunnel information.
     */
    function tunnelInfo(
        uint64 tunnelId,
        address addr
    ) external view returns (TunnelInfo memory);

    /**
     * @dev Returns the originator hash of the given tunnel ID and address.
     *
     * @param tunnelId The ID of the tunnel.
     * @param addr The target contract address.
     *
     * @return bytes32 The originator hash of the tunnel.
     */
    function originatorHash(
        uint64 tunnelId,
        address addr
    ) external view returns (bytes32);

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

    /**
     * @dev Returns the source chain ID hash.
     */
    function sourceChainIdHash() external view returns (bytes32);

    /**
     * @dev Returns the target chain ID hash.
     */
    function targetChainIdHash() external view returns (bytes32);
}
