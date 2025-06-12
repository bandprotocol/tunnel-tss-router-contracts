// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./PacketConsumer.sol";

/**
 * @title PacketConsumerFactory
 * @notice Deploys PacketConsumer contracts for unique task IDs and keeps a registry.
 *         Anyone can call to create a consumer for a given `taskId`. If one already
 *         exists, its address is returned instead of deploying again.
 */
contract PacketConsumerFactory is Ownable2Step {
    /* ========== ERRORS ========== */

    /// @notice Thrown when the provided owner address is zero.
    error InvalidOwner();

    /// @notice Thrown when the provided tunnelRouter address is zero.
    error InvalidRouter();

    /* ========== EVENTS ========== */

    /// @notice Emitted each time a new PacketConsumer is deployed.
    /// @param taskId       The unique task ID (indexed).
    /// @param tunnelRouter The router contract the consumer will use (indexed).
    /// @param owner        The owner of the new consumer (indexed).
    /// @param consumer     The address of the newly deployed consumer.
    event PacketConsumerCreated(
        uint256 indexed taskId,
        address indexed tunnelRouter,
        address indexed owner,
        address consumer
    );

    /* ========== STATE ========== */

    /// @notice Maps each task ID to its deployed PacketConsumer (or address(0)).
    mapping(uint256 => address) public taskIdToConsumer;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param initialOwner The address to transfer factory ownership to.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Deploys (or returns) a PacketConsumer for a given `taskId`.
     * @dev    If one already exists, just returns its address. Otherwise:
     *         1. Validates inputs
     *         2. Deploys `new PacketConsumer(tunnelRouter, owner)`
     *         3. Stores it in `taskIdToConsumer`
     *         4. Emits `PacketConsumerCreated`
     * @param owner        The owner to assign to the new consumer (must be non-zero).
     * @param tunnelRouter The tunnel router contract address (must be non-zero).
     * @param taskId       A unique ID for this consumer instance.
     * @return consumer    The address of the deployed—or pre-existing—consumer.
     */
    function createPacketConsumer(
        address owner,
        address tunnelRouter,
        uint256 taskId
    ) external returns (address consumer) {
        if (owner == address(0)) revert InvalidOwner();
        if (tunnelRouter == address(0)) revert InvalidRouter();

        // If already deployed, return that
        consumer = taskIdToConsumer[taskId];
        if (consumer != address(0)) {
            return consumer;
        }

        // Deploy & register
        PacketConsumer newConsumer = new PacketConsumer(tunnelRouter, owner);
        consumer = address(newConsumer);
        taskIdToConsumer[taskId] = consumer;

        emit PacketConsumerCreated(taskId, tunnelRouter, owner, consumer);
    }
}
