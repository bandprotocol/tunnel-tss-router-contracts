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

abstract contract BaseTunnelRouter is
    Initializable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    ITunnelRouter
{
    using StringAddress for string;
    using PacketDecoder for bytes;

    ITssVerifier public tssVerifier;
    IVault public vault;

    // Additional gas estimated for relaying the message;
    // does not include the gas cost for executing the target contract.
    uint256 public additionalGasUsed;
    // The maximum gas limit can be used when calling the target contract.
    uint256 public callbackGasLimit;

    mapping(uint64 => mapping(address => bool)) public isActive; // tunnelID => targetAddr => isActive
    mapping(uint64 => mapping(address => uint64)) public sequence; // tunnelID => targetAddr => sequence

    uint[50] __gap;

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IVault vault_,
        address initialOwner,
        uint256 additionalGasUsed_,
        uint256 callbackGasLimit_
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        vault = vault_;

        _setAdditionalGasUsed(additionalGasUsed_);
        _setCallbackGasLimit(callbackGasLimit_);
    }

    /**
     * @dev Sets the additionalGasUsed being used in relaying message.
     * @param additionalGasUsed_ The new additional gas used amount.
     */
    function setAdditionalGasUsed(
        uint256 additionalGasUsed_
    ) external onlyOwner {
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
    function relay(
        bytes calldata message,
        address randomAddr,
        uint256 signature
    ) external whenNotPaused {
        PacketDecoder.TssMessage memory tssMessage = message.decodeTssMessage();
        PacketDecoder.Packet memory packet = tssMessage.packet;
        address targetAddr = packet.targetAddr.toAddress();

        // check if the message is valid.
        if (!isActive[packet.tunnelId][targetAddr]) {
            revert InactiveTargetContract(targetAddr);
        }
        if (sequence[packet.tunnelId][targetAddr] + 1 != packet.sequence) {
            revert InvalidSequence(
                sequence[packet.tunnelId][targetAddr] + 1,
                packet.sequence
            );
        }

        // verify signature.
        bool isValid = tssVerifier.verify(
            keccak256(message),
            randomAddr,
            signature
        );
        if (!isValid) {
            revert InvalidSignature();
        }

        // update the sequence.
        sequence[packet.tunnelId][targetAddr] = packet.sequence;

        // forward the message to the target contract.
        uint256 gasLeft = gasleft();
        bool isReverted = false;
        try
            IDataConsumer(targetAddr).process{gas: callbackGasLimit}(tssMessage)
        {} catch {
            isReverted = true;
        }

        emit MessageProcessed(
            packet.tunnelId,
            targetAddr,
            packet.sequence,
            isReverted
        );

        // charge a fee from the target contract.
        uint256 fee = _routerFee(gasLeft - gasleft() + additionalGasUsed);
        vault.collectFee(packet.tunnelId, targetAddr, fee);

        // deactivate the target contract if the remaining balance is under the threshold.
        if (_isBalanceUnderThreshold(packet.tunnelId, targetAddr)) {
            _deactivate(packet.tunnelId, targetAddr);
        }

        (bool ok, ) = payable(msg.sender).call{value: fee}("");
        if (!ok) {
            revert TokenTransferFailed(msg.sender);
        }
    }

    /**
     * @dev See {ITunnelRouter-activate}.
     */
    function activate(uint64 tunnelId, uint64 latestSeq) external payable {
        if (isActive[tunnelId][msg.sender]) {
            revert ActiveTargetContract(msg.sender);
        }

        vault.deposit{value: msg.value}(tunnelId, msg.sender);

        // cannot activate if the remaining balance is under the threshold.
        if (_isBalanceUnderThreshold(tunnelId, msg.sender)) {
            revert InsufficientRemainingBalance(tunnelId, msg.sender);
        }

        isActive[tunnelId][msg.sender] = true;
        sequence[tunnelId][msg.sender] = latestSeq;
        emit Activated(tunnelId, msg.sender, latestSeq);
    }

    /**
     * @dev See {ITunnelRouter-deactivate}.
     */
    function deactivate(uint64 tunnelId) external {
        if (!isActive[tunnelId][msg.sender]) {
            revert InactiveTargetContract(msg.sender);
        }

        _deactivate(tunnelId, msg.sender);
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
    function tunnelInfo(
        uint64 tunnelId,
        address addr
    ) external view returns (TunnelInfo memory) {
        return
            TunnelInfo({
                isActive: isActive[tunnelId][addr],
                latestSequence: sequence[tunnelId][addr],
                balance: vault.balance(tunnelId, addr)
            });
    }

    function _isBalanceUnderThreshold(
        uint64 tunnelId,
        address addr
    ) internal view returns (bool) {
        uint256 remainingBalance = vault.balance(tunnelId, addr);
        return remainingBalance < minimumBalanceThreshold();
    }

    /// @dev Deactivates the (contract address, tunnelId).
    function _deactivate(uint64 tunnelId, address addr) internal {
        isActive[tunnelId][addr] = false;
        emit Deactivated(tunnelId, addr, sequence[tunnelId][addr]);
    }

    /// @dev Calculates the fee for the router.
    function _routerFee(uint256 gasUsed) internal view virtual returns (uint) {
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
