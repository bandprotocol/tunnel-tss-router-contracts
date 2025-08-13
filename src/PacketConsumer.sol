// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IPacketConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/Address.sol";
import "./libraries/PacketDecoder.sol";

contract PacketConsumer is IPacketConsumer, Ownable2Step {
    // The tunnel router contract.
    address public immutable tunnelRouter;

    // Mapping between a signal ID and its corresponding latest price object.
    mapping(bytes32 => Price) internal _prices;

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
     * @dev A helper function for query a price with a string of signal
     */
    function prices(string calldata _s) external view returns (Price memory) {
        return _prices[stringToRightAlignedBytes32(_s)];
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

            emit SignalPriceUpdated(
                packet.signals[i].signal,
                packet.signals[i].price,
                packet.timestamp
            );
        }
    }

    /**
     * @dev See {IPacketConsumer-activate}.
     */
    function activate(
        uint64 tunnelId,
        uint64 latestSeq
    ) external payable onlyOwner {
        ITunnelRouter(tunnelRouter).activate{value: msg.value}(
            tunnelId,
            latestSeq
        );
    }

    /**
     * @dev See {IPacketConsumer-deactivate}.
     */
    function deactivate(uint64 tunnelId) external onlyOwner {
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
}
