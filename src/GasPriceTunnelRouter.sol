// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./BaseTunnelRouter.sol";

contract GasPriceTunnelRouter is BaseTunnelRouter {
    uint public gasPrice;

    event SetGasPrice(uint gasPrice);

    function initialize(
        ITssVerifier tssVerifier_,
        IBandReserve bandReserve_,
        address initialOwner,
        uint additionalGas_,
        uint maxGasUsedProcess_,
        uint maxGasUsedCollectFee_,
        uint gasPrice_
    ) public initializer {
        __BaseRouter_init(
            tssVerifier_,
            bandReserve_,
            initialOwner,
            additionalGas_,
            maxGasUsedProcess_,
            maxGasUsedCollectFee_
        );

        gasPrice = gasPrice_;
    }

    /// @dev Set the gas price.
    /// @param gasPrice_ is the new gas price.
    function setGasPrice(uint gasPrice_) public virtual onlyOwner {
        gasPrice = gasPrice_;
        emit SetGasPrice(gasPrice_);
    }

    function _routerFee(
        uint gasUsed
    ) internal view virtual override returns (uint) {
        return gasPrice * gasUsed;
    }
}
