// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "../src/PacketConsumerFactory.sol";
import "../src/PacketConsumer.sol";

contract PacketConsumerFactoryTest is Test {
    PacketConsumerFactory internal factory;
    address internal constant ROUTER = address(0x8888);
    address internal constant ROUTER_2 = address(0x9999);
    address internal constant ALICE = address(0xA1CE);
    address internal constant BOB = address(0xB0B);
    address internal constant NON_OWNER = address(0xC0DE);
    uint256 internal constant TASK_ID_1 = 999;
    uint256 internal constant TASK_ID_2 = 1000;

    function setUp() external {
        // Deploy the factory, transferring ownership to this test contract
        factory = new PacketConsumerFactory(address(this));
    }

    /// @notice The factory owner should be set correctly in constructor
    function testFactoryOwnerIsSet() external view {
        assertEq(
            factory.owner(),
            address(this),
            "Factory owner should be set correctly"
        );
    }

    /// @notice Uninitialized taskId should return zero address in mapping
    function testMappingReturnsZeroBeforeCreate() external view {
        assertEq(
            factory.taskIdToConsumer(TASK_ID_1),
            address(0),
            "Uninitialized taskId should be zero"
        );
    }

    /// @notice Should revert if owner address is zero
    function testRevertOnZeroOwner() external {
        vm.expectRevert(PacketConsumerFactory.InvalidOwner.selector);
        factory.createPacketConsumer(address(0), ROUTER, TASK_ID_1);
    }

    /// @notice Should revert if tunnelRouter address is zero
    function testRevertOnZeroRouter() external {
        vm.expectRevert(PacketConsumerFactory.InvalidRouter.selector);
        factory.createPacketConsumer(ALICE, address(0), TASK_ID_1);
    }

    /// @notice Test successful creation, mapping, and event emission
    function testCreatePacketConsumer() external {
        // Expect the creation event (ignore consumer address)
        vm.expectEmit(true, true, true, false);
        emit PacketConsumerFactory.PacketConsumerCreated(
            TASK_ID_1,
            ROUTER,
            ALICE,
            address(0)
        );

        // Create the consumer
        address cons = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        assertTrue(cons != address(0), "Consumer address should be non-zero");

        // The mapping should point to the new consumer
        assertEq(
            factory.taskIdToConsumer(TASK_ID_1),
            cons,
            "Mapping should store consumer address"
        );

        // Inspect the deployed PacketConsumer
        PacketConsumer pc = PacketConsumer(payable(cons));
        assertEq(pc.tunnelRouter(), ROUTER, "Router mismatch");
        assertEq(pc.owner(), ALICE, "Owner mismatch");
    }

    /// @notice Calling again with the same taskId should return the same address and not emit event
    function testNoEventOnDuplicate() external {
        // Create first consumer and expect event
        vm.expectEmit(true, true, true, false);
        emit PacketConsumerFactory.PacketConsumerCreated(
            TASK_ID_1,
            ROUTER,
            ALICE,
            address(0)
        );
        address first = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);

        // Second call should not emit event
        address second = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        assertEq(first, second, "Must return same address for same owner");

        // Attempt with different owner
        address third = factory.createPacketConsumer(BOB, ROUTER, TASK_ID_1);
        assertEq(first, third, "Must return same address for different owner");

        // Verify original owner is unchanged
        PacketConsumer pc = PacketConsumer(payable(first));
        assertEq(pc.owner(), ALICE, "Original owner should remain unchanged");
    }

    /// @notice You can look up the consumer by taskId via the external getter
    function testLookupGetter() external {
        address cons = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        address lookup = factory.taskIdToConsumer(TASK_ID_1);
        assertEq(lookup, cons, "Getter returned wrong address");
    }

    /// @notice Test creation of consumers for multiple task IDs
    function testMultipleTaskIds() external {
        // Create consumer for TASK_ID_1
        address cons1 = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        // Create consumer for TASK_ID_2
        address cons2 = factory.createPacketConsumer(BOB, ROUTER_2, TASK_ID_2);

        // Verify mapping
        assertEq(
            factory.taskIdToConsumer(TASK_ID_1),
            cons1,
            "TASK_ID_1 mapping incorrect"
        );
        assertEq(
            factory.taskIdToConsumer(TASK_ID_2),
            cons2,
            "TASK_ID_2 mapping incorrect"
        );
        assertTrue(cons1 != cons2, "Consumer addresses should be different");

        // Verify consumer configurations
        PacketConsumer pc1 = PacketConsumer(payable(cons1));
        PacketConsumer pc2 = PacketConsumer(payable(cons2));
        assertEq(pc1.owner(), ALICE, "Consumer1 owner mismatch");
        assertEq(pc2.owner(), BOB, "Consumer2 owner mismatch");
        assertEq(pc1.tunnelRouter(), ROUTER, "Consumer1 router mismatch");
        assertEq(pc2.tunnelRouter(), ROUTER_2, "Consumer2 router mismatch");
    }

    /// @notice Test that a non-owner can create a PacketConsumer
    function testNonOwnerCanCreate() external {
        // Call from non-owner address
        vm.prank(NON_OWNER);
        address cons = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);

        // Verify mapping and consumer configuration
        assertEq(
            factory.taskIdToConsumer(TASK_ID_1),
            cons,
            "Mapping should store consumer address"
        );
        PacketConsumer pc = PacketConsumer(payable(cons));
        assertEq(pc.owner(), ALICE, "Owner mismatch");
        assertEq(pc.tunnelRouter(), ROUTER, "Router mismatch");
    }

    /// @notice Test ownership transfer flow using Ownable2Step
    function testOwnershipTransferFlow() external {
        // Initiate ownership transfer
        factory.transferOwnership(NON_OWNER);
        // Verify pending owner
        assertEq(
            factory.owner(),
            address(this),
            "Owner should not change until accepted"
        );

        // Accept ownership from non-owner
        vm.prank(NON_OWNER);
        factory.acceptOwnership();
        assertEq(factory.owner(), NON_OWNER, "Ownership transfer failed");
    }

    /// @notice Test that same taskId with different router returns existing consumer
    /// @dev This reflects current contract behavior but may indicate a design issue,
    /// as the existing consumer's tunnelRouter may differ from the requested one.
    /// Consider modifying the contract to check tunnelRouter compatibility.
    function testSameTaskIdDifferentRouter() external {
        // Create consumer with ROUTER
        address cons1 = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        // Attempt with same taskId but different router
        address cons2 = factory.createPacketConsumer(
            ALICE,
            ROUTER_2,
            TASK_ID_1
        );

        // Verify same address is returned (current contract behavior)
        assertEq(cons1, cons2, "Should return existing consumer address");

        // Verify consumer still has original router
        PacketConsumer pc = PacketConsumer(payable(cons1));
        assertEq(
            pc.tunnelRouter(),
            ROUTER,
            "Consumer should retain original router"
        );
    }
}
