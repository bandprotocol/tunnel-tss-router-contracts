// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./interfaces/IVault.sol";
import "./BaseTunnelRouter.sol";

contract GasPriceTunnelRouter is BaseTunnelRouter {
    struct GasFeeInfo {
        uint256 gasPrice;
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
        uint256 gasPrice_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            vault_,
            chainID_,
            initialOwner,
            additionalGas_,
            maxAllowableCallbackGasLimit_
        );

        _setGasFee(GasFeeInfo(gasPrice_));
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

    function _routerFee(
        uint256 gasUsed
    ) internal view virtual override returns (uint) {
        return gasFee.gasPrice * gasUsed;
    }
}
