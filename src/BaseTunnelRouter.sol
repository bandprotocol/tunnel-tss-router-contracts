// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./interfaces/IBandReserve.sol";
import "./interfaces/ITssVerifier.sol";
import "./interfaces/IDataConsumer.sol";
import "./PacketDecoder.sol";

abstract contract BaseTunnelRouter is
    Initializable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    PacketDecoder
{
    ITssVerifier public tssVerifier;
    IBandReserve public bandReserve;

    string public chainID;
    uint public additionalGas;
    uint public maxGasUsedProcess;
    uint public maxGasUsedCollectFee;

    mapping(address => bool) public isInactive;
    mapping(address => uint64) public nonces;

    uint[50] __gap;

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

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IBandReserve bandReserve_,
        string memory chainID_,
        address initialOwner,
        uint additionalGas_,
        uint maxGasUsedProcess_,
        uint maxGasUsedCollectFee_
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        bandReserve = bandReserve_;
        chainID = chainID_;
        additionalGas = additionalGas_;
        maxGasUsedProcess = maxGasUsedProcess_;
        maxGasUsedCollectFee = maxGasUsedCollectFee_;
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
        TssMessage memory tssMessage = _decodeTssMessage(message);
        Packet memory packet = tssMessage.packet;
        require(
            nonces[address(targetAddr)] + 1 == packet.nonce,
            "TunnelRouter: !nonce"
        );

        // validate the hashOriginator.
        bytes32 hashOriginator = _toHashOriginator(
            packet.tunnelID,
            address(targetAddr),
            chainID
        );
        require(
            tssMessage.hashOriginator == hashOriginator,
            "TunnelRouter: !hashOriginator"
        );

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
        uint fee = _routerFee(gasLeft - gasleft() + additionalGas);
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

    /// @dev calculate the fee for the router.
    function _routerFee(uint gasUsed) internal view virtual returns (uint) {
        gasUsed; // Shh

        return 0;
    }

    receive() external payable {}
}
