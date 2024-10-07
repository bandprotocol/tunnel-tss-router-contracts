// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./BaseTunnelRouter.sol";

contract PrioritiyFeeTunnelRouter is BaseTunnelRouter {
    struct GasFeeInfo {
        uint baseFee;
        uint priorityFee;
    }

    GasFeeInfo public gasFee;

    event SetGasFee(GasFeeInfo gasFee);

    function initialize(
        ITssVerifier tssVerifier_,
        IBandReserve bandReserve_,
        address initialOwner,
        uint additionalGas_,
        uint maxGasUsedProcess_,
        uint maxGasUsedCollectFee_,
        uint baseFee_,
        uint priorityFee_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            bandReserve_,
            initialOwner,
            additionalGas_,
            maxGasUsedProcess_,
            maxGasUsedCollectFee_
        );

        setGasFee(GasFeeInfo(baseFee_, priorityFee_));
    }

    /// @dev Set the gas fee information.
    /// @param gasFee_ is the new gas fee information.
    function setGasFee(GasFeeInfo memory gasFee_) public virtual onlyOwner {
        gasFee = gasFee_;
        emit SetGasFee(gasFee_);
    }

    function _routerFee(
        uint gasUsed
    ) internal view virtual override returns (uint) {
        GasFeeInfo memory _gasFee = gasFee;
        return (_gasFee.priorityFee + _gasFee.baseFee) * gasUsed;
    }
}
