# Interfaces

### TunnelRouter

```solidity
interface ITunnelRouter {
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
     * @return TunnelInfo The tunnel information.
     */
    function tunnelInfo(uint64 tunnelId, address addr) external view returns (TunnelInfo memory);

    /**
     * @dev Returns the originator hash of the given tunnel ID and address.
     *
     * @param tunnelId The ID of the tunnel.
     * @param addr The target contract address.
     *
     * @return bytes32 The originator hash of the tunnel.
     */
    function originatorHash(uint64 tunnelId, address addr) external view returns (bytes32);

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
```

### TssVerifier

```solidity

interface ITssVerifier {
    /**
     * @dev Verifies the signature of the message against the given signature.
     *
     * The contract is not allowed to verify the message with obsolete public key.
     *
     * @param hashedMessage The hashed message to be verified.
     * @param randomAddr The random address generated during TSS signature processing.
     * @param signature The tss signature.
     * @return true If the signature is valid, false otherwise.
     */
    function verify(bytes32 hashedMessage, address randomAddr, uint256 signature) external view returns (bool);

    /**
     * @dev Adds a new public key with proof from the current group.
     *
     * @param message The message being used for updating public key.
     * @param randomAddr The address form of the commitment R.
     * @param s The Schnorr signature.
     */
    function addPubKeyWithProof(bytes calldata message, address randomAddr, uint256 s) external;

    /**
     * @dev Adds the new public key by the owner.
     *
     * @param timestamp The timestamp of the new public key.
     * @param parity The parity value of the new public key.
     * @param px The x-coordinate value of the new public key.
     */
    function addPubKeyByOwner(uint64 timestamp, uint8 parity, uint256 px) external;
}
```

### Vault

```solidity

interface IVault {
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
     * @dev Collects the fee from the given originator hash.
     *
     * This function should be called by the tunnelRouter contract only.
     *
     * @param originatorHash The originator hash of the account to which the token is withdrawn.
     * @param to The account to which the sender is withdrawing tokens to.
     * @param amount the amount of tokens to withdraw.
     */
    function collectFee(bytes32 originatorHash, address to, uint256 amount) external;

    /**
     * @dev Returns the balance of the account.
     *
     * @param tunnelId The ID of the tunnel to check the balance.
     * @param account The account to check the balance.
     */
    function balance(uint64 tunnelId, address account) external view returns (uint256);

    /**
     * @dev Returns the balance of the account by the given originator hash.
     *
     * @param originatorHash The originator hash of the account to which the token is deposited.
     */
    function getBalanceByOriginatorHash(bytes32 originatorHash) external view returns (uint256);

    /**
     * @dev Returns the tunnel router contract address.
     */
    function tunnelRouter() external view returns (address);
}
```
