// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IPacketConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/Address.sol";
import "./libraries/PacketDecoder.sol";

contract PacketConsumer is IPacketConsumer, Ownable2Step {
    // An object that contains the price of a signal ID.
    struct Price {
        uint64 price;
        int64 timestamp;
    }

    // The tunnel router contract.
    address public immutable tunnelRouter;

    // The tunnel ID that this contract is consuming; cannot be immutable or else the create2
    // will result in different address.
    uint64 public tunnelId;
    // Mapping between a signal ID and its corresponding latest price object.
    mapping(bytes32 => Price) internal _prices;

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    constructor(address tunnelRouter_, address initialOwner) Ownable(initialOwner) {
        tunnelRouter = tunnelRouter_;
    }

    /**
     * @dev A helper function for converting a string to a bytes32 (right aligned)
     */
    function signalStringToBytes32RightAlign(
        string memory _s
    ) public pure returns (bytes32 s) {
        assembly {
            s := mload(add(_s, 32))
        }
        uint256 shift = (32 - bytes(_s).length) * 8;
        s >>= shift;
    }

    /**
     * @dev A helper function for query a price with a string of signal
     */
    function prices(string calldata _s) external view returns(Price memory) {
        return _prices[signalStringToBytes32RightAlign(_s)];
    }

    /**
     * @dev See {IPacketConsumer-process}.
     */
    function process(PacketDecoder.TssMessage memory data) external onlyTunnelRouter {
        PacketDecoder.Packet memory packet = data.packet;
        for (uint256 i = 0; i < packet.signals.length; i++) {
            _prices[packet.signals[i].signal] = Price({price: packet.signals[i].price, timestamp: packet.timestamp});

            emit SignalPriceUpdated(packet.signals[i].signal, packet.signals[i].price, packet.timestamp);
        }
    }

    /**
     * @dev See {IPacketConsumer-activate}.
     */
    function activate(uint64 latestSeq) external payable onlyOwner {
        ITunnelRouter(tunnelRouter).activate{value: msg.value}(tunnelId, latestSeq);
    }

    /**
     * @dev See {IPacketConsumer-deactivate}.
     */
    function deactivate() external onlyOwner {
        ITunnelRouter(tunnelRouter).deactivate(tunnelId);
    }

    /**
     * @dev See {IPacketConsumer-deposit}.
     */
    function deposit() external payable {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.deposit{value: msg.value}(tunnelId, address(this));
    }

    /**
     * @dev See {IPacketConsumer-withdraw}.
     */
    function withdraw(uint256 amount) external onlyOwner {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdraw(tunnelId, msg.sender, amount);
    }

    /**
     * @dev See {IPacketConsumer-withdrawAll}.
     */
    function withdrawAll() external onlyOwner {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdrawAll(tunnelId, msg.sender);
    }

    ///@dev Sets the tunnel ID of the contract.
    function setTunnelId(uint64 tunnelId_) external onlyOwner {
        tunnelId = tunnelId_;
    }
}
