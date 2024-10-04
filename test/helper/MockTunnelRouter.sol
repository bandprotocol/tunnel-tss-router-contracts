// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../../src/interfaces/IDataConsumer.sol";

contract MockTunnelRouter {
    function relay(bytes calldata message, IDataConsumer target) external {
        target.process(message);
    }

    function collectFee(IDataConsumer target, uint fee) external {
        target.collectFee(fee);
    }

    receive() external payable {}

    fallback() external payable {}
}
