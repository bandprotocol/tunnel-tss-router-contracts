// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../interfaces/IDataConsumer.sol";
import "../interfaces/ITssVerifier.sol";
import "../interfaces/ITunnelRouter.sol";
import "../interfaces/IVault.sol";

import "../libraries/PacketDecoder.sol";
import "../libraries/StringAddress.sol";
import "../libraries/Originator.sol";

abstract contract BaseTunnelRouter is Initializable, Ownable2StepUpgradeable, PausableUpgradeable, ITunnelRouter {
    using StringAddress for string;
    using PacketDecoder for bytes;

    ITssVerifier public tssVerifier;
    IVault public vault;

    struct TunnelDetail {
        bool isActive;
        uint64 sequence;
    }

    // Additional gas estimated for relaying the message;
    // does not include the gas cost for executing the target contract.
    uint256 public additionalGasUsed;
    // The maximum gas limit can be used when calling the target contract.
    uint256 public callbackGasLimit;

    bytes32 private _sourceChainIdHash;

    mapping(bytes32 => TunnelDetail) public tunnelDetails; // tunnelID => TunnelDetail

    uint256[50] internal __gap;

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IVault vault_,
        address initialOwner,
        uint256 additionalGasUsed_,
        uint256 callbackGasLimit_,
        string calldata sourceChainId
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        vault = vault_;

        _sourceChainIdHash = keccak256(bytes(sourceChainId));

        _setAdditionalGasUsed(additionalGasUsed_);
        _setCallbackGasLimit(callbackGasLimit_);
    }

    /**
     * @dev Sets the additionalGasUsed being used in relaying message.
     * @param additionalGasUsed_ The new additional gas used amount.
     */
    function setAdditionalGasUsed(uint256 additionalGasUsed_) external onlyOwner {
        _setAdditionalGasUsed(additionalGasUsed_);
    }

    /**
     * @dev Sets the callback gas limit.
     *
     * @param callbackGasLimit_ the maximum gas limit can be used when calling the target contract.
     */
    function setCallbackGasLimit(uint256 callbackGasLimit_) external onlyOwner {
        _setCallbackGasLimit(callbackGasLimit_);
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev See {ITunnelRouter-relay}.
     */
    function relay(bytes calldata message, address randomAddr, uint256 signature) external whenNotPaused {
        PacketDecoder.TssMessage memory tssMessage = message.decodeTssMessage();
        PacketDecoder.Packet memory packet = tssMessage.packet;
        address targetAddr = packet.targetAddr.toAddress();
        bytes32 originatorHash = Originator.hash(_sourceChainIdHash, packet.tunnelId, targetAddr);

        // check if the message is valid.
        if (tssMessage.encoderType == PacketDecoder.EncoderType.Undefined) {
            revert UndefinedEncoderType();
        }
        if (!tunnelDetails[originatorHash].isActive) {
            revert InactiveTunnel(targetAddr);
        }
        if (tunnelDetails[originatorHash].sequence + 1 != packet.sequence) {
            revert InvalidSequence(tunnelDetails[originatorHash].sequence + 1, packet.sequence);
        }

        // verify signature.
        bool isValid = tssVerifier.verify(keccak256(message), randomAddr, signature);
        if (!isValid) {
            revert InvalidSignature();
        }

        // update the sequence.
        tunnelDetails[originatorHash].sequence = packet.sequence;

        // forward the message to the target contract.
        uint256 gasLeft = gasleft();
        bool isReverted = false;
        try IDataConsumer(targetAddr).process{gas: callbackGasLimit}(tssMessage) {}
        catch {
            isReverted = true;
        }

        emit MessageProcessed(originatorHash, packet.sequence, isReverted);

        // charge a fee from the target contract.
        uint256 fee = _routerFee(gasLeft - gasleft() + additionalGasUsed);
        vault.collectFee(packet.tunnelId, targetAddr, fee);

        // deactivate the target contract if the remaining balance is under the threshold.
        if (_isBalanceUnderThreshold(packet.tunnelId, targetAddr)) {
            _deactivate(originatorHash);
        }

        (bool ok,) = payable(msg.sender).call{value: fee}("");
        if (!ok) {
            revert TokenTransferFailed(msg.sender);
        }
    }

    /**
     * @dev See {ITunnelRouter-activate}.
     */
    function activate(uint64 tunnelId, uint64 latestSeq) external payable {
        bytes32 originatorHash = Originator.hash(_sourceChainIdHash, tunnelId, msg.sender);

        if (tunnelDetails[originatorHash].isActive) {
            revert ActiveTunnel(msg.sender);
        }

        vault.deposit{value: msg.value}(tunnelId, msg.sender);

        // cannot activate if the remaining balance is under the threshold.
        if (_isBalanceUnderThreshold(tunnelId, msg.sender)) {
            revert InsufficientRemainingBalance(tunnelId, msg.sender);
        }

        tunnelDetails[originatorHash].isActive = true;
        tunnelDetails[originatorHash].sequence = latestSeq;
        emit Activated(originatorHash, latestSeq);
    }

    /**
     * @dev See {ITunnelRouter-deactivate}.
     */
    function deactivate(uint64 tunnelId) external {
        bytes32 originatorHash = Originator.hash(_sourceChainIdHash, tunnelId, msg.sender);

        if (!tunnelDetails[originatorHash].isActive) {
            revert InactiveTunnel(msg.sender);
        }

        _deactivate(originatorHash);
    }

    /**
     * @dev See {ITunnelRouter-minimumBalanceThreshold}.
     */
    function minimumBalanceThreshold() public view override returns (uint256) {
        return _routerFee(additionalGasUsed + callbackGasLimit);
    }

    /**
     * @dev See {ITunnelRouter-tunnelInfo}.
     */
    function tunnelInfo(uint64 tunnelId, address addr) external view returns (TunnelInfo memory) {
        bytes32 originatorHash = Originator.hash(_sourceChainIdHash, tunnelId, addr);
        return TunnelInfo({
            isActive: tunnelDetails[originatorHash].isActive,
            latestSequence: tunnelDetails[originatorHash].sequence,
            balance: vault.balance(tunnelId, addr)
        });
    }

    function isActive(bytes32 originatorHash) external view override returns (bool) {
        return tunnelDetails[originatorHash].isActive;
    }

    function sequence(bytes32 originatorHash) external view override returns (uint64) {
        return tunnelDetails[originatorHash].sequence;
    }

    function _isBalanceUnderThreshold(uint64 tunnelId, address addr) internal view returns (bool) {
        uint256 remainingBalance = vault.balance(tunnelId, addr);
        return remainingBalance < minimumBalanceThreshold();
    }

    /// @dev Deactivates the (contract address, tunnelId).
    function _deactivate(bytes32 originatorHash) internal {
        tunnelDetails[originatorHash].isActive = false;
        emit Deactivated(originatorHash, tunnelDetails[originatorHash].sequence);
    }

    /// @dev Calculates the fee for the router.
    function _routerFee(uint256 gasUsed) internal view virtual returns (uint256) {
        gasUsed; // Shh

        return 0;
    }

    /// @dev Sets callbackGasLimit and emit an event.
    function _setCallbackGasLimit(uint256 callbackGasLimit_) internal {
        callbackGasLimit = callbackGasLimit_;
        emit CallbackGasLimitSet(callbackGasLimit_);
    }

    /// @dev Sets additionalGasUsed and emit an event.
    function _setAdditionalGasUsed(uint256 additionalGasUsed_) internal {
        additionalGasUsed = additionalGasUsed_;
        emit AdditionalGasUsedSet(additionalGasUsed_);
    }

    /// @dev the vault contract send fees to the contract when relayer relays a message.
    receive() external payable {}
}
