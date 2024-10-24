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
