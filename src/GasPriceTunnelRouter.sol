// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./interfaces/IVault.sol";
import "./BaseTunnelRouter.sol";

contract GasPriceTunnelRouter is BaseTunnelRouter {
    struct GasFeeInfo {
        uint gasPrice;
    }

    GasFeeInfo public gasFee;

    event SetGasFee(GasFeeInfo gasFee);

    function initialize(
        ITssVerifier tssVerifier_,
        IVault vault_,
        string memory chainID_,
        address initialOwner,
        uint additionalGas_,
        uint maxGasUsedProcess_,
        uint maxGasUsedCollectFee_,
        uint gasPrice_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            vault_,
            chainID_,
            initialOwner,
            additionalGas_,
            maxGasUsedProcess_,
            maxGasUsedCollectFee_
        );

        _setGasFee(GasFeeInfo(gasPrice_));
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
        uint gasUsed
    ) internal view virtual override returns (uint) {
        return gasFee.gasPrice * gasUsed;
    }
}
