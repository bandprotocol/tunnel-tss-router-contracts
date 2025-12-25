// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PacketConsumer.sol";

/**
 * @title PacketConsumerFactory
 * @notice Deploys PacketConsumer contracts for unique task IDs and tracks them in a registry.
 * @dev Only accounts with CREATOR_ROLE can create consumers.
 *      Returns existing consumer for duplicate task IDs, checking tunnelRouter compatibility.
 */
contract PacketConsumerFactory is AccessControl {
    /* ========== ERRORS ========== */

    /// @notice Thrown when the owner address is zero.
    error InvalidInputOwner();

    /// @notice Thrown when the tunnelRouter address is zero.
    error InvalidInputRouter();

    /* ========== EVENTS ========== */

    /// @notice Emitted when a new PacketConsumer is deployed.
    /// @param taskId       Unique task ID.
    /// @param tunnelRouter Router contract used by the consumer.
    /// @param owner        Owner of the new consumer.
    /// @param creator      Address with CREATOR_ROLE that deployed the consumer.
    event PacketConsumerCreated(
        uint256 indexed taskId,
        address tunnelRouter,
        address owner,
        address creator
    );

    /* ========== STATE ========== */

    /// @notice Role identifier for accounts allowed to create consumers.
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    /// @notice Maps task IDs to their deployed PacketConsumer addresses.
    mapping(uint256 => address) public taskIdToConsumer;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Sets up the contract, granting admin and creator roles to an initial account.
     * @param adminAndCreator The address to receive the DEFAULT_ADMIN_ROLE and CREATOR_ROLE.
     */
    constructor(address adminAndCreator) {
        if (adminAndCreator == address(0)) revert InvalidInputOwner();

        _grantRole(DEFAULT_ADMIN_ROLE, adminAndCreator);
        _grantRole(CREATOR_ROLE, adminAndCreator);
    }

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
    ) external onlyRole(CREATOR_ROLE) returns (address consumer) {
        if (owner == address(0)) revert InvalidInputOwner();
        if (tunnelRouter == address(0)) revert InvalidInputRouter();

        consumer = taskIdToConsumer[taskId];
        // Check for existing consumer
        if (consumer != address(0)) {
            return consumer;
        }

        // Deploy & register new consumer
        PacketConsumer newConsumer = new PacketConsumer(tunnelRouter);
        consumer = address(newConsumer);
        taskIdToConsumer[taskId] = consumer;
        
        emit PacketConsumerCreated(taskId, tunnelRouter, owner, msg.sender);

        newConsumer.grantRole(newConsumer.TUNNEL_ACTIVATOR_ROLE(), owner);
        newConsumer.revokeRole(newConsumer.TUNNEL_ACTIVATOR_ROLE(), address(this));
        
        newConsumer.grantRole(DEFAULT_ADMIN_ROLE, owner);
        newConsumer.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
    }
}
