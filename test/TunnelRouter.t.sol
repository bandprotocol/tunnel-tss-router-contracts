// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "./helper/MockTssVerifier.sol";
import "../src/Vault.sol";
import "../src/router/PriorityFeeTunnelRouter.sol";
import "../src/interfaces/ITunnelRouter.sol";

contract TunnelRouterTest is Test {
    PriorityFeeTunnelRouter router;

    function setUp() public {
        router = new PriorityFeeTunnelRouter();
        router.initialize(
            new MockTssVerifier(),
            new Vault(),
            address(this),
            75000 * 1e18,
            14000,
            175000,
            10,
            keccak256("bandchain"),
            keccak256("testnet-evm")
        );
    }

    function testSetTssVerifier() public {
        MockTssVerifier newVerifier = new MockTssVerifier();
        address testSender = address(0x42);
        
        vm.prank(testSender);
        vm.expectRevert();
        router.setTssVerifier(newVerifier);

        vm.expectEmit(true, false, false, true);
        emit ITunnelRouter.TssVerifierSet(newVerifier);
        router.setTssVerifier(newVerifier);
        assertEq(address(router.tssVerifier()), address(newVerifier));
    }
}
