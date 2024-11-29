// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IVault {
    // ========================================
    // Events
    // ========================================

    /**
     * @notice Emitted when the tunnel router contract address is set.
     *
     * @param tunnelRouter The new tunnel router contract address.
     */
    event TunnelRouterSet(address tunnelRouter);

    /**
     * @notice Emitted when the caller deposit native token into the contract.
     *
     * @param originatorHash The originator hash of the account to which the token is deposited.
     * @param from The account from which the token is deposited.
     * @param amount The amount of tokens deposited.
     */
    event Deposited(bytes32 indexed originatorHash, address indexed from, uint256 amount);

    /**
     * @notice Emitted when the caller withdraw native token from the contract.
     *
     * @param originatorHash The originator hash of the account to which the token is deposited.
     * @param to The account to which the token is withdrawn.
     * @param amount The amount of tokens withdrawn.
     */
    event Withdrawn(bytes32 indexed originatorHash, address indexed to, uint256 amount);

    // ========================================
    // Custom Errors
    // ========================================

    /**
     * @notice The caller is not the tunnelRouter contract.
     */
    error UnauthorizedTunnelRouter();

    /**
     * @notice Reverts if the balance is insufficient to allow the withdrawal without exceeding the threshold.
     */
    error WithdrawnAmountExceedsThreshold();

    /**
     * @notice Reverts if the tunnel is active.
     */
    error TunnelIsActive();

    /**
     * @notice Reverts if contract cannot send fee to the specific address.
     *
     * @param addr The address to which the token transfer failed.
     */
    error TokenTransferFailed(address addr);

    // ========================================
    // Functions
    // ========================================

    /**
     * @dev Deposits the native tokens into the vault on behalf of the given account and tunnelID.
     * The deposit amount is provided via `msg.value`.
     *
     * @param tunnelId The ID of the tunnel into which the sender is depositing tokens.
     * @param to The account into which the sender is depositing tokens
     */
    function deposit(uint64 tunnelId, address to) external payable;

    /**
     * @dev Withdraws native tokens from the sender's account associated with the given tunnelID.
     *
     * @param tunnelId the ID of the tunnel from which the sender is withdrawing tokens.
     * @param to The account to which the sender is withdrawing tokens to.
     * @param amount the amount of tokens to withdraw.
     */
    function withdraw(uint64 tunnelId, address to, uint256 amount) external;

    /**
     * @dev Withdraws the entire deposit from the sender's account for the specified tunnel ID.
     * @param to The account to which the sender is withdrawing tokens to.
     * @param tunnelId the ID of the tunnel from which the sender is withdrawing tokens.
     */
    function withdrawAll(uint64 tunnelId, address to) external;

    /**
     * @dev Collects the fee from the account and the given tunnel ID.
     *
     * This function should be called by the tunnelRouter contract only.
     *
     * @param tunnelId the ID of the tunnel from which the caller is withdrawing tokens.
     * @param account The account from which the caller is withdrawing tokens.
     * @param amount the amount of tokens to withdraw.
     */
    function collectFee(uint64 tunnelId, address account, uint256 amount) external;

    /**
     * @dev Returns the balance of the account.
     *
     * @param tunnelId The ID of the tunnel to check the balance.
     * @param account The account to check the balance.
     */
    function balance(uint64 tunnelId, address account) external view returns (uint256);

    /**
     * @dev Returns the tunnel router contract address.
     */
    function tunnelRouter() external view returns (address);
}
