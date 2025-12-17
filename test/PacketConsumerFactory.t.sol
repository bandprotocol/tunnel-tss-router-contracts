// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import "../src/PacketConsumerFactory.sol";
import "../src/PacketConsumer.sol";

contract PacketConsumerFactoryTest is Test {
    PacketConsumerFactory internal factory;
    address internal constant ROUTER = address(0x8888);
    address internal constant ROUTER_2 = address(0x9999);
    address internal constant ALICE = address(0xA1CE);
    address internal constant BOB = address(0xB0B);
    address internal constant OWNER = address(0x011e7);
    address internal constant CREATOR = address(0xc7ea707);

    uint256 internal constant TASK_ID_1 = 999;
    uint256 internal constant TASK_ID_2 = 1000;

    // Duplicates PacketConsumerFactory's CREATOR_ROLE for test convenience.
    bytes32 internal constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    // Duplicates AccessControl's DEFAULT_ADMIN_ROLE for test convenience.
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() external {
        // Deploy the factory
        factory = new PacketConsumerFactory(OWNER);

        // Grant CREATOR_ROLE to the creator
        vm.prank(OWNER);
        factory.grantRole(CREATOR_ROLE, CREATOR);
    }

    /// @notice The admin and creator roles should be set correctly in the constructor
    function testRolesAreSet() external view {
        // check owner
        assertTrue(
            factory.hasRole(DEFAULT_ADMIN_ROLE, OWNER),
            "Owner should have admin role"
        );
        assertTrue(
            factory.hasRole(CREATOR_ROLE, OWNER),
            "Owner should have creator role"
        );

        // check creator
        assertFalse(
            factory.hasRole(DEFAULT_ADMIN_ROLE, CREATOR),
            "Creator should not have admin role"
        );
        assertTrue(
            factory.hasRole(CREATOR_ROLE, CREATOR),
            "Creator should have creator role"
        );

        // check alice
        assertFalse(
            factory.hasRole(DEFAULT_ADMIN_ROLE, ALICE),
            "Alice should not have any role"
        );
        assertFalse(
            factory.hasRole(CREATOR_ROLE, ALICE),
            "Alice should not have any role"
        );

        // check BOB
        assertFalse(
            factory.hasRole(DEFAULT_ADMIN_ROLE, BOB),
            "BOB should not have any role"
        );
        assertFalse(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should not have any role"
        );
    }

    /// @notice An uninitialized taskId should return a zero address in the mapping
    function testMappingReturnsZeroBeforeCreate() external view {
        assertEq(
            factory.taskIdToConsumer(TASK_ID_1),
            address(0),
            "Uninitialized taskId should be zero"
        );
    }

    /// @notice The public getter for the mapping should return the correct consumer address
    function testLookupGetter() external {
        vm.prank(CREATOR);
        address cons = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        address lookup = factory.taskIdToConsumer(TASK_ID_1);
        assertEq(lookup, cons, "Getter returned wrong address");
    }

    /// @notice Should revert if the owner address for the new consumer is zero
    function testRevertOnZeroOwner() external {
        vm.expectRevert(PacketConsumerFactory.InvalidInputOwner.selector);
        vm.prank(CREATOR);
        factory.createPacketConsumer(address(0), ROUTER, TASK_ID_1);
    }

    /// @notice Should revert if the tunnelRouter address for the new consumer is zero
    function testRevertOnZeroRouter() external {
        vm.expectRevert(PacketConsumerFactory.InvalidInputRouter.selector);
        vm.prank(CREATOR);
        factory.createPacketConsumer(ALICE, address(0), TASK_ID_1);
    }

    /// @notice Should revert if the caller lacks the CREATOR_ROLE
    function testRevertOnNonCreator() external {
        // Expect a revert with AccessControl's specific error for unauthorized accounts
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                BOB,
                CREATOR_ROLE
            )
        );
        vm.prank(BOB);
        factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
    }

    /// @notice Test successful creation, mapping, and event emission by an authorized creator
    function testCreatePacketConsumer() external {
        // Expect the PacketConsumerCreated event, including the new creator parameter
        vm.expectEmit();
        emit PacketConsumerFactory.PacketConsumerCreated(
            TASK_ID_1,
            ROUTER,
            ALICE,
            CREATOR
        );
        vm.prank(CREATOR);
        address cons = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        assertTrue(cons != address(0), "Consumer address should be non-zero");

        assertEq(
            factory.taskIdToConsumer(TASK_ID_1),
            cons,
            "Mapping should store consumer address"
        );

        PacketConsumer pc = PacketConsumer(payable(cons));
        assertEq(pc.tunnelRouter(), ROUTER, "Router mismatch");
    }

    /// @notice Calling again with the same taskId should return the same address and not emit event
    function testNoEventOnDuplicate() external {
        // Create first consumer and expect event
        vm.expectEmit();
        emit PacketConsumerFactory.PacketConsumerCreated(
            TASK_ID_1,
            ROUTER,
            ALICE,
            CREATOR
        );
        vm.prank(CREATOR);
        address first = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);

        // Start recording logs to check for absence of event
        vm.recordLogs();
        vm.prank(CREATOR);
        address second = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);

        // Get recorded logs and check that no PacketConsumerCreated event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0, "No event should be emitted");
        // Verify the same address is returned
        assertEq(first, second, "Must return same address for same owner");

        // Attempt with different owner
        vm.recordLogs();
        vm.prank(CREATOR);
        address third = factory.createPacketConsumer(BOB, ROUTER, TASK_ID_1);

        logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "No event should be emitted");
        assertEq(first, third, "Must return same address for different owner");
    }

    /// @notice A creator should be able to create consumers for multiple distinct task IDs
    function testMultipleTaskIds() external {
        vm.prank(CREATOR);
        address cons1 = factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
        vm.prank(CREATOR);
        address cons2 = factory.createPacketConsumer(BOB, ROUTER_2, TASK_ID_2);

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
        assertTrue(
            cons1 != cons2,
            "Consumer addresses for different task IDs should be different"
        );
    }

    /// @notice Test that a non-creator can not create a PacketConsumer
    function testNonCreatorCanNotCreate() external {
        // Simulate a call from ALICE, who does not have CREATOR_ROLE
        // Expect a revert with AccessControlUnauthorizedAccount error
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                CREATOR_ROLE
            )
        );
        factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);

        // Same for BOB
        vm.prank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                BOB,
                CREATOR_ROLE
            )
        );
        factory.createPacketConsumer(BOB, ROUTER_2, TASK_ID_2);
    }

    /// @notice Only the owner (with DEFAULT_ADMIN_ROLE) can grant roles like CREATOR_ROLE
    function testOnlyOwnerCanGrantRoles() external {
        // Attempt to grant CREATOR_ROLE as ALICE (no roles)
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        factory.grantRole(CREATOR_ROLE, BOB);

        // Attempt to grant CREATOR_ROLE as BOB (no roles)
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                BOB,
                DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(BOB);
        factory.grantRole(CREATOR_ROLE, BOB);

        // Attempt to grant CREATOR_ROLE as CREATOR (has CREATOR_ROLE but not DEFAULT_ADMIN_ROLE)
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                CREATOR,
                DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(CREATOR);
        factory.grantRole(CREATOR_ROLE, BOB);

        // Verify BOB still does not have CREATOR_ROLE
        assertFalse(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should not have CREATOR_ROLE"
        );

        // Grant CREATOR_ROLE as OWNER (should succeed)
        vm.prank(OWNER);
        factory.grantRole(CREATOR_ROLE, BOB);

        // Verify BOB now has CREATOR_ROLE
        assertTrue(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should have CREATOR_ROLE after owner grants it"
        );
    }

    /// @notice Tests the full lifecycle of granting and revoking the CREATOR_ROLE
    function testCreatorRoleManagement() external {
        // Verify BOB initially lacks CREATOR_ROLE and cannot create
        assertFalse(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should not have CREATOR_ROLE initially"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                BOB,
                CREATOR_ROLE
            )
        );
        vm.prank(BOB);
        factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);

        // Non-admin (ALICE) cannot grant CREATOR_ROLE to BOB
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        factory.grantRole(CREATOR_ROLE, BOB);

        // OWNER grants CREATOR_ROLE to BOB
        vm.expectEmit();
        vm.prank(OWNER);
        emit IAccessControl.RoleGranted(CREATOR_ROLE, BOB, OWNER);
        factory.grantRole(CREATOR_ROLE, BOB);
        assertTrue(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should have CREATOR_ROLE after grant"
        );

        // BOB can now create a PacketConsumer
        vm.prank(BOB);
        address consumer = factory.createPacketConsumer(
            ALICE,
            ROUTER,
            TASK_ID_1
        );
        assertTrue(
            consumer != address(0),
            "BOB should create PacketConsumer successfully"
        );

        // Non-admin (ALICE) cannot revoke BOB's CREATOR_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        factory.revokeRole(CREATOR_ROLE, BOB);

        // OWNER revokes CREATOR_ROLE from BOB
        vm.expectEmit();
        vm.prank(OWNER);
        emit IAccessControl.RoleRevoked(CREATOR_ROLE, BOB, OWNER);
        factory.revokeRole(CREATOR_ROLE, BOB);
        assertFalse(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should not have CREATOR_ROLE after revoke"
        );

        // BOB can no longer create a PacketConsumer
        vm.prank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                BOB,
                CREATOR_ROLE
            )
        );
        factory.createPacketConsumer(ALICE, ROUTER, TASK_ID_1);
    }

    /// @notice Tests the full lifecycle of granting and revoking the DEFAULT_ADMIN_ROLE
    function testAdminRoleManagement() external {
        // Verify ALICE (non-admin) cannot grant DEFAULT_ADMIN_ROLE to BOB
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                DEFAULT_ADMIN_ROLE
            )
        );
        factory.grantRole(DEFAULT_ADMIN_ROLE, BOB);

        // Verify ALICE cannot revoke OWNER's DEFAULT_ADMIN_ROLE
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ALICE,
                DEFAULT_ADMIN_ROLE
            )
        );
        factory.revokeRole(DEFAULT_ADMIN_ROLE, OWNER);

        // OWNER grants DEFAULT_ADMIN_ROLE to BOB
        vm.prank(OWNER);
        vm.expectEmit();
        emit IAccessControl.RoleGranted(DEFAULT_ADMIN_ROLE, BOB, OWNER);
        factory.grantRole(DEFAULT_ADMIN_ROLE, BOB);
        assertTrue(
            factory.hasRole(DEFAULT_ADMIN_ROLE, BOB),
            "BOB should have DEFAULT_ADMIN_ROLE after grant"
        );

        // Verify BOB can perform admin actions (e.g., grant CREATOR_ROLE to ALICE)
        vm.prank(BOB);
        factory.grantRole(CREATOR_ROLE, ALICE);
        assertTrue(
            factory.hasRole(CREATOR_ROLE, ALICE),
            "ALICE should have CREATOR_ROLE after BOB grants it"
        );

        // OWNER revokes BOB's DEFAULT_ADMIN_ROLE
        vm.prank(OWNER);
        vm.expectEmit();
        emit IAccessControl.RoleRevoked(DEFAULT_ADMIN_ROLE, BOB, OWNER);
        factory.revokeRole(DEFAULT_ADMIN_ROLE, BOB);
        assertFalse(
            factory.hasRole(DEFAULT_ADMIN_ROLE, BOB),
            "BOB should not have DEFAULT_ADMIN_ROLE after revoke"
        );

        // Verify BOB can no longer perform admin actions
        vm.prank(BOB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                BOB,
                DEFAULT_ADMIN_ROLE
            )
        );
        factory.grantRole(CREATOR_ROLE, ALICE);

        // Verify OWNER still has DEFAULT_ADMIN_ROLE and can perform admin actions
        vm.prank(OWNER);
        factory.grantRole(CREATOR_ROLE, BOB);
        assertTrue(
            factory.hasRole(CREATOR_ROLE, BOB),
            "BOB should have CREATOR_ROLE after OWNER grants it"
        );
    }
}
