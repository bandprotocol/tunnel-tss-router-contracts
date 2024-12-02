// SPDX-License-Identifier: MIT
// ref: https://gist.github.com/Y5Yash/721a5f5c3e392a6a28f47db1d3114501
// ref: https://github.com/ethereum/ercs/blob/master/ERCS/erc-55.md

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./Address.sol";

library Originator {
    bytes4 internal constant ORIGINATOR_HASH_PREFIX = 0x72ebe83d;

    ///@dev get the originator hash from the given parameters.
    function hash(bytes32 sourceChainIdHash, bytes32 targetChainIdHash, uint64 tunnelId, address account)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                ORIGINATOR_HASH_PREFIX,
                sourceChainIdHash,
                tunnelId,
                targetChainIdHash,
                keccak256(bytes(Address.toChecksumString(account)))
            )
        );
    }
}
