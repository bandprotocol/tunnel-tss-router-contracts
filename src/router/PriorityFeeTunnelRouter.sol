// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/math/Math.sol";
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
        uint256 packedAdditionalGasFuncCoeffs,
        uint256 maxCalldataBytes_,
        uint256 callbackGasLimit_,
        uint256 priorityFee_,
        bytes32 sourceChainIdHash_,
        bytes32 targetChainIdHash_,
        bool refundable_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            vault_,
            packedAdditionalGasFuncCoeffs,
            maxCalldataBytes_,
            callbackGasLimit_,
            sourceChainIdHash_,
            targetChainIdHash_,
            refundable_
        );

        _setGasFee(GasFeeInfo(priorityFee_));
    }

    /**
     * @dev Sets the gas fee information.
     * @param gasFee_ The new gas fee information.
     */
    function setGasFee(GasFeeInfo memory gasFee_) public onlyRole(GAS_FEE_UPDATER_ROLE) {
        _setGasFee(gasFee_);
    }

    function _setGasFee(GasFeeInfo memory gasFee_) internal {
        gasFee = gasFee_;
        emit SetGasFee(gasFee_);
    }

    function _routerFee(
        uint256 gasUsed
    ) internal view virtual override returns (uint256) {
        uint256 effectiveGasPrice = Math.min(
            tx.gasprice,
            gasFee.priorityFee + block.basefee
        );
        return effectiveGasPrice * gasUsed;
    }
}
