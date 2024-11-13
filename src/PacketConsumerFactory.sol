// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./PacketConsumer.sol";

contract PacketConsumerFactory {
    bytes32 immutable hashedSourceChainId;
    bytes32 immutable hashedTargetChainId;
    address immutable tunnelRouter;

    constructor(
        bytes32 hashedSourceChainId_,
        bytes32 hashedTargetChainId_,
        address tunnelRouter_
    ) {
        hashedSourceChainId = hashedSourceChainId_;
        hashedTargetChainId = hashedTargetChainId_;
        tunnelRouter = tunnelRouter_;
    }

    function createPacketConsumer(
        uint64 tunnelId,
        string memory customSalt
    ) external returns (PacketConsumer) {
        bytes32 salt = keccak256(bytes(customSalt));

        PacketConsumer packetConsumer = new PacketConsumer{salt: salt}(
            tunnelRouter,
            address(this),
            hashedSourceChainId,
            hashedTargetChainId,
            msg.sender
        );

        packetConsumer.setTunnelId(tunnelId);
        return packetConsumer;
    }

    function getPacketConsumerAddress(
        string memory customSalt
    ) external view returns (address) {
        bytes32 salt = keccak256(bytes(customSalt));
        bytes32 hashedbytecode = keccak256(
            abi.encodePacked(
                type(PacketConsumer).creationCode,
                abi.encode(
                    tunnelRouter,
                    address(this),
                    hashedSourceChainId,
                    hashedTargetChainId,
                    msg.sender
                )
            )
        );

        bytes32 hashAddr = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, hashedbytecode)
        );

        return address(uint160(uint256(hashAddr)));
    }
}
