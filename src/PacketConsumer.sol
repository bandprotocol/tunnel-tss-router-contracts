// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IDataConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/PacketDecoder.sol";
import "./TssVerifier.sol";

contract PacketConsumer is IDataConsumer, Ownable2Step {
    // An object that contains the price of a signal Id.
    struct Price {
        uint64 price;
        int64 timestamp;
    }

    // The tunnel router contract.
    address public immutable tunnelRouter;
    // The hash originator of the feeds price data that this contract consumes.
    bytes32 public immutable hashOriginator;
    // The tunnel Id that this contract is consuming.
    uint64 public immutable tunnelId;
    // Mapping between a signal Id and its corresponding latest price object.
    mapping(bytes32 => Price) public prices;

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    constructor(
        address tunnelRouter_,
        bytes32 hashOriginator_,
        uint64 tunnelId_,
        address initialOwner
    ) Ownable(initialOwner) {
        tunnelRouter = tunnelRouter_;
        hashOriginator = hashOriginator_;
        tunnelId = tunnelId_;
    }

    /**
     * @dev See {IDataConsumer-process}.
     */
    function process(
        PacketDecoder.TssMessage memory data
    ) external onlyTunnelRouter {
        if (data.hashOriginator != hashOriginator) {
            revert InvalidHashOriginator();
        }

        PacketDecoder.Packet memory packet = data.packet;
        for (uint256 i = 0; i < packet.signals.length; i++) {
            prices[packet.signals[i].signal] = Price({
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
     * @dev See {IDataConsumer-activate}.
     */
    function activate(uint64 latestSeq) external payable onlyOwner {
        ITunnelRouter(tunnelRouter).activate{value: msg.value}(
            tunnelId,
            latestSeq
        );
    }

    /**
     * @dev See {IDataConsumer-deactivate}.
     */
    function deactivate() external onlyOwner {
        ITunnelRouter(tunnelRouter).deactivate(tunnelId);
    }

    /**
     * @dev See {IDataConsumer-deposit}.
     */
    function deposit() external payable {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.deposit{value: msg.value}(tunnelId, address(this));
    }

    /**
     * @dev See {IDataConsumer-withdraw}.
     */
    function withdraw(uint256 amount) external onlyOwner {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdraw(tunnelId, amount);

        // send the remaining balance to the caller.
        uint256 balance = address(this).balance;
        (bool ok, ) = payable(msg.sender).call{value: balance}("");
        if (!ok) {
            revert TokenTransferFailed(msg.sender);
        }
    }

    /**
     * @dev See {IDataConsumer-withdrawAll}.
     */
    function withdrawAll() external onlyOwner {
        IVault vault = ITunnelRouter(tunnelRouter).vault();

        vault.withdrawAll(tunnelId);

        // send the remaining balance to the caller.
        uint256 balance = address(this).balance;
        (bool ok, ) = payable(msg.sender).call{value: balance}("");
        if (!ok) {
            revert TokenTransferFailed(msg.sender);
        }
    }

    ///@dev the contract receive eth from the vault contract when user call withdraw.
    receive() external payable {}
}
