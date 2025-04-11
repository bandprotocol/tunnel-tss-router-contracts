// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./BaseTunnelRouter.sol";

contract PriorityFeeTunnelRouter is BaseTunnelRouter {
    struct GasFeeInfo {
        uint256 priorityFee;
    }

    GasFeeInfo public gasFee;

    event SetGasFee(GasFeeInfo gasFee);

    function initialize(
        ITssVerifier tssVerifier_,
        IVault vault_,
        address initialOwner,
        uint256 additionalGas_,
        uint256 callbackGasLimit_,
        uint256 priorityFee_,
        bytes32 sourceChainIdHash_,
        bytes32 targetChainIdHash_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            vault_,
            initialOwner,
            additionalGas_,
            callbackGasLimit_,
            sourceChainIdHash_,
            targetChainIdHash_
        );

        _setGasFee(GasFeeInfo(priorityFee_));
    }

    /**
     * @dev Sets the gas fee information.
     * @param gasFee_ The new gas fee information.
     */
    function setGasFee(GasFeeInfo memory gasFee_) public onlyOwner {
        _setGasFee(gasFee_);
    }

    function _setGasFee(GasFeeInfo memory gasFee_) internal {
        gasFee = gasFee_;
        emit SetGasFee(gasFee_);
    }

    function _routerFee(uint256 gasUsed) internal view virtual override returns (uint256) {
        return (gasFee.priorityFee + block.basefee) * gasUsed;
    }
}
