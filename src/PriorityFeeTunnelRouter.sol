// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./BaseTunnelRouter.sol";

contract PrioritiyFeeTunnelRouter is BaseTunnelRouter {
    struct GasFeeInfo {
        uint256 priorityFee;
    }

    GasFeeInfo public gasFee;

    event SetGasFee(GasFeeInfo gasFee);

    function initialize(
        ITssVerifier tssVerifier_,
        IVault vault_,
        bytes32 chainID_,
        address initialOwner,
        uint256 additionalGas_,
        uint256 maxAllowableCallbackGasLimit_,
        uint256 priorityFee_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            vault_,
            chainID_,
            initialOwner,
            additionalGas_,
            maxAllowableCallbackGasLimit_
        );

        _setGasFee(GasFeeInfo(priorityFee_));
    }

    /**
     * @dev Set the gas fee information.
     * @param gasFee_ is the new gas fee information.
     */
    function setGasFee(GasFeeInfo memory gasFee_) public onlyOwner {
        _setGasFee(gasFee_);
    }

    function _setGasFee(GasFeeInfo memory gasFee_) internal {
        gasFee = gasFee_;
        emit SetGasFee(gasFee_);
    }

    function _routerFee(
        uint256 gasUsed
    ) internal view virtual override returns (uint) {
        GasFeeInfo memory _gasFee = gasFee;
        return (_gasFee.priorityFee + block.basefee) * gasUsed;
    }
}
