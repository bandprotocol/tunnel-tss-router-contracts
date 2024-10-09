// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IDataConsumer {
    /**
     * @dev Process the relayed message.
     *
     * The relayed message should be evaluated from the tunnelRouter contract and
     * should be verified from the tssVerifier contract before forwarding to the contract.
     *
     * @param message The tss message that is relayed from the tunnelRouter contract.
     */
    function process(bytes calldata message) external;

    /**
     * @dev The tunnelRouter contract address.
     */
    function tunnelRouter() external view returns (address);

    /**
     * @dev Activate the tunnelID on tunnelRouter contract.
     *
     * This also deposit tokens into the vault and set the latest sequence on the
     * tunnelRouter contract if the current deposit in the vault contract is over a threshold;
     * otherwise, the transaction is reverted.
     *
     * This function should be called by the owner of the contract only.
     *
     * @param tunnelID The tunnelID that the sender contract is activating.
     * @param latestSeq The new sequence of the tunnelID.
     */
    function activate(uint64 tunnelID, uint64 latestSeq) external payable;

    /**
     * @dev Deactivate the tunnelID on tunnelRouter contract.
     *
     * This also withdraws the tokens from the vault contract if there is existing deposit
     * in the contract.
     *
     * @param tunnelID is the tunnelID that the sender contract is deactivating.
     */
    function deactivate(uint64 tunnelID) external;
}
