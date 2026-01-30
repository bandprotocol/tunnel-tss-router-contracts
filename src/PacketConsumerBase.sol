// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IPacketConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/PacketDecoder.sol";

abstract contract PacketConsumerBase is IPacketConsumer, AccessControl {
    // The tunnel router contract.
    address public immutable tunnelRouter;

    // Role identifier for accounts allowed to activate/deactivate tunnel.
    bytes32 public constant TUNNEL_ACTIVATOR_ROLE = keccak256("TUNNEL_ACTIVATOR_ROLE");

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    constructor(
        address tunnelRouter_
    ) {
        tunnelRouter = tunnelRouter_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TUNNEL_ACTIVATOR_ROLE, msg.sender);
    }

    /**
     * @dev Converts a string to a right-aligned bytes32 value
     */
    function stringToRightAlignedBytes32(
        string memory _s
    ) public pure returns (bytes32 s) {
        if (bytes(_s).length > 32) {
            revert StringInputExceedsBytes32(_s);
        }
        assembly {
            s := mload(add(_s, 32))
        }
        s >>= (32 - bytes(_s).length) * 8;
    }

    /**
     * @dev See {IPacketConsumer-activate}.
     */
    function activate(
        uint64 tunnelId,
        uint64 latestSeq
    ) external payable onlyRole(TUNNEL_ACTIVATOR_ROLE) {
        ITunnelRouter(tunnelRouter).activate{value: msg.value}(
            tunnelId,
            latestSeq
        );
    }

    /**
     * @dev See {IPacketConsumer-deactivate}.
     */
    function deactivate(uint64 tunnelId) external onlyRole(TUNNEL_ACTIVATOR_ROLE) {
        ITunnelRouter(tunnelRouter).deactivate(tunnelId);
    }

    /**
     * @dev See {IPacketConsumer-deposit}.
     */
    function deposit(uint64 tunnelId) external payable {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.deposit{value: msg.value}(tunnelId, address(this));
    }

    /**
     * @dev See {IPacketConsumer-withdraw}.
     */
    function withdraw(uint64 tunnelId, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdraw(tunnelId, msg.sender, amount);
    }

    /**
     * @dev See {IPacketConsumer-withdrawAll}.
     */
    function withdrawAll(uint64 tunnelId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdrawAll(tunnelId, msg.sender);
    }

    /// @dev Grants `TUNNEL_ACTIVATOR_ROLE` to `accounts`
    function grantTunnelActivatorRole(address[] calldata accounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _grantRole(TUNNEL_ACTIVATOR_ROLE, accounts[i]);
        }
    }

    /// @dev Revokes `TUNNEL_ACTIVATOR_ROLE` from `accounts`
    function revokeTunnelActivatorRole(address[] calldata accounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _revokeRole(TUNNEL_ACTIVATOR_ROLE, accounts[i]);
        }
    }
}
