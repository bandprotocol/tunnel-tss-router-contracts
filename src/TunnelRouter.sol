// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./interfaces/IBandReserve.sol";
import "./interfaces/ITssVerifier.sol";
import "./interfaces/IDataConsumer.sol";
import "./PacketDecoder.sol";

contract TunnelRouter is
    Initializable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    PacketDecoder
{
    ITssVerifier public tssVerifier;
    IBandReserve public bandReserve;

    uint public gasPrice;
    uint public additionalGas;
    uint public maxGasUsedProcess;
    uint public maxGasUsedCollectFee;

    mapping(address => bool) public isInactive;
    mapping(address => uint64) public nonces;

    uint[49] __gap;

    event SetGasPrice(uint gasPrice);
    event SetMaxGasUsedProcess(uint maxGasUsedProcess);
    event SetMaxGasUsedCollectFee(uint maxGasUsedCollectFee);
    event ProcessMessage(
        address indexed targetAddr,
        uint64 indexed nonce,
        bool isReverted
    );
    event CollectFee(address indexed targetAddr, uint fee);
    event Reactivate(address indexed targetAddr, uint64 latestNonce);
    event Deactivate(address indexed targetAddr, uint64 latestNonce);

    function initialize(
        ITssVerifier tssVerifier_,
        IBandReserve bandReserve_,
        address initialOwner,
        uint gasPrice_,
        uint additionalGas_,
        uint maxGasUsedProcess_,
        uint maxGasUsedCollectFee_
    ) public initializer {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        bandReserve = bandReserve_;
        gasPrice = gasPrice_;
        additionalGas = additionalGas_;
        maxGasUsedProcess = maxGasUsedProcess_;
        maxGasUsedCollectFee = maxGasUsedCollectFee_;
    }

    /// @dev set the gas price.
    /// @param gasPrice_ is the new gas price.
    function setGasPrice(uint gasPrice_) external onlyOwner {
        gasPrice = gasPrice_;
        emit SetGasPrice(gasPrice);
    }

    /// @dev set the additionalGas being used in relaying message.
    /// @param additionalGas_ is the new additional gas amount.
    function setBaseGasUsed(uint additionalGas_) external onlyOwner {
        additionalGas = additionalGas_;
    }

    /// @dev set the maximum gas used in calling process.
    /// @param maxGasUsedProcess_ is the maximum gas used in calling process.
    function setMaxGasUsedProcess(uint maxGasUsedProcess_) external onlyOwner {
        maxGasUsedProcess = maxGasUsedProcess_;
        emit SetMaxGasUsedProcess(maxGasUsedProcess);
    }

    /// @dev set the maximum gas used in calling collectFee.
    /// @param maxGasUsedCollectFee_ is the maximum gas used in calling collectFee.
    function setMaxGasUsedCollectFee(
        uint maxGasUsedCollectFee_
    ) external onlyOwner {
        maxGasUsedCollectFee = maxGasUsedCollectFee_;
        emit SetMaxGasUsedCollectFee(maxGasUsedCollectFee);
    }

    /// @dev pause the contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev unpause the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev relay the message to the target contract.
    /// @param message is the message to be relayed.
    /// @param targetAddr is the target contract address.
    /// @param rAddr is the r address of the signature.
    /// @param signature is the signature of the message.
    function relay(
        bytes calldata message,
        IDataConsumer targetAddr,
        address rAddr,
        uint256 signature
    ) external whenNotPaused {
        // check if the target is active.
        require(!isInactive[address(targetAddr)], "TunnelRouter: !active");

        // decoding and validate the message.
        Packet memory packet = _decodePacket(message);
        require(
            nonces[address(targetAddr)] + 1 == packet.nonce,
            "TunnelRouter: !nonce"
        );

        // TODO: require confirmation.
        // require(packet.chainID == block.chainid, "TunnelRouter: !chainID");
        // require(
        //     packet.targetAddr == address(targetAddr),
        //     "TunnelRouter: !targetAddr"
        // );

        // update the nonce.
        nonces[address(targetAddr)] = packet.nonce;

        // verify signature.
        bool success = tssVerifier.verify(message, rAddr, signature);
        require(success, "TunnelRouter: !verify");

        // forward the message to the target contract.
        uint gasLeft = gasleft();
        bool isReverted = false;
        try targetAddr.process{gas: maxGasUsedProcess}(message) {} catch {
            isReverted = true;
        }
        emit ProcessMessage(address(targetAddr), packet.nonce, isReverted);

        // charge a fee from the target contract.
        uint fee = (gasLeft - gasleft() + additionalGas) * gasPrice;
        isReverted = false;
        try targetAddr.collectFee{gas: maxGasUsedCollectFee}(fee) {} catch {
            isReverted = true;
        }

        // check the collectedFee is enough to cover the fee. If not, withdraw from the reserve
        // and deactivate the target contract.
        uint collectedFee = address(this).balance;
        emit CollectFee(address(targetAddr), collectedFee);

        if (isReverted || fee > collectedFee) {
            uint remainingFee = fee > collectedFee ? fee - collectedFee : 0;
            bandReserve.borrowOnBehalf(remainingFee, address(targetAddr));

            _deactivate(address(targetAddr));

            collectedFee = collectedFee + remainingFee;
        }

        (bool ok, ) = payable(msg.sender).call{value: collectedFee}("");
        require(ok, "TunnelRouter: Fail to send fee");
    }

    /// @dev reactivate the target contract by repaying the debt and set the nonce of the target contract.
    /// @param latestNonce is the new latest nonce of the sender contract.
    function reactivate(uint64 latestNonce) external payable {
        require(isInactive[msg.sender], "TunnelRouter: !inactive");
        require(
            msg.value >= bandReserve.debt(msg.sender),
            "TunnelRouter: !debt"
        );
        if (msg.value > 0) {
            bandReserve.repay{value: msg.value}(msg.sender);
        }

        isInactive[msg.sender] = false;
        nonces[msg.sender] = latestNonce;
        emit Reactivate(msg.sender, latestNonce);
    }

    /// @dev deactivate the sender contract.
    function deactivate() external {
        _deactivate(msg.sender);
    }

    /// @dev deactivate the given address.
    function _deactivate(address addr) internal {
        isInactive[addr] = true;
        emit Deactivate(addr, nonces[addr]);
    }

    receive() external payable {}
}
