// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./interfaces/IDataConsumer.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/PacketDecoder.sol";
import "./libraries/Address.sol";
import "./TssVerifier.sol";

contract PacketConsumer is IDataConsumer, Ownable2Step {
    // An object that contains the price of a signal Id.
    struct Price {
        uint64 price;
        int64 timestamp;
    }

    // The tunnel router contract.
    address public immutable tunnelRouter;
    // The hashed source chain Id that this contract is consuming from.
    bytes32 public immutable hashedSourceChainId;
    // The hashed target chain Id that this contract is at.
    bytes32 public immutable hashedTargetChainId;

    // The tunnel Id that this contract is consuming; cannot be immutable or else the create2
    // will result in different address.
    uint64 public tunnelId;
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
        bytes32 hashedSourceChainId_,
        bytes32 hashedTargetChainId_,
        address initialOwner
    ) Ownable(initialOwner) {
        hashedSourceChainId = hashedSourceChainId_;
        hashedTargetChainId = hashedTargetChainId_;
        tunnelRouter = tunnelRouter_;
    }

    /**
     * @dev See {IDataConsumer-process}.
     */
    function process(
        PacketDecoder.TssMessage memory data
    ) external onlyTunnelRouter {
        if (data.hashOriginator != hashOriginator()) {
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

    ///@dev Sets the tunnel Id of the contract.
    function setTunnelId(uint64 tunnelId_) external onlyOwner {
        tunnelId = tunnelId_;
    }

    ///@dev Returns the hash of the originator of the packet.
    function hashOriginator() public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    bytes4(0xa466d313), // keccak("tunnelOriginatorPrefix")[:4]
                    hashedSourceChainId,
                    tunnelId,
                    keccak256(bytes(Address.toChecksumString(address(this)))),
                    hashedTargetChainId
                )
            );
    }

    ///@dev The contract receive eth from the vault contract when user call withdraw.
    receive() external payable {}
}
