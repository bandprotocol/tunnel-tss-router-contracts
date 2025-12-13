// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IPacketConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/PacketDecoder.sol";

contract PacketConsumer is IPacketConsumer, Ownable2Step, AccessControl {
    // The tunnel router contract.
    address public immutable tunnelRouter;

    // Mapping between a signal ID and its corresponding latest price object.
    mapping(bytes32 => Price) internal _prices;

    // Role identifier for accounts allowed to activate/deactivate tunnel.
    bytes32 public constant TUNNEL_ACTIVATOR_ROLE = keccak256("TUNNEL_ACTIVATOR_ROLE");

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    constructor(
        address tunnelRouter_,
        address initialOwner
    ) Ownable(initialOwner) {
        tunnelRouter = tunnelRouter_;

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(TUNNEL_ACTIVATOR_ROLE, initialOwner);
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
     * @dev See {IPacketConsumer-getPrice}.
     */
    function getPrice(string calldata _signalId) external view returns (Price memory) {
        Price memory price = _prices[stringToRightAlignedBytes32(_signalId)];
        if (price.price == 0) {
            revert SignalIdNotAvailable(_signalId);
        }
        return price;
    }

    /**
     * @dev See {IPacketConsumer-getPriceBatch}.
     */
    function getPriceBatch(string[] calldata _signalIds) external view returns (Price[] memory) {
        Price[] memory priceList = new Price[](_signalIds.length);
        for (uint i = 0; i < _signalIds.length; i++) {
            Price memory price = _prices[stringToRightAlignedBytes32(_signalIds[i])];
            if (price.price == 0) {
                revert SignalIdNotAvailable(_signalIds[i]);
            }
            priceList[i] = price;
        }
        return priceList;
    }

    /**
     * @dev See {IPacketConsumer-process}.
     */
    function process(
        PacketDecoder.TssMessage memory data
    ) external onlyTunnelRouter {
        PacketDecoder.Packet memory packet = data.packet;
        for (uint256 i = 0; i < packet.signals.length; i++) {
            _prices[packet.signals[i].signal] = Price({
                price: packet.signals[i].price,
                timestamp: packet.timestamp
            });
        }
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
    function withdraw(uint64 tunnelId, uint256 amount) external onlyOwner {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdraw(tunnelId, msg.sender, amount);
    }

    /**
     * @dev See {IPacketConsumer-withdrawAll}.
     */
    function withdrawAll(uint64 tunnelId) external onlyOwner {
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
