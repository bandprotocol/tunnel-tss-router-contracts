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

    // The Id of the chain. Used to validate messages received from the tunnel.
    bytes32 public chainId;
    // Additional gas estimated for relaying the message;
    // does not include the gas cost for executing the target contract.
    uint256 public additionalGasUsed;
    // The maximum allowable gas to be used when calling the target contract.
    uint256 public maxAllowableCallbackGasLimit;

    mapping(uint64 => mapping(address => bool)) public isActive; // tunnelId => targetAddr => isActive
    mapping(uint64 => mapping(address => uint64)) public sequence; // tunnelId => targetAddr => sequence

    uint[50] __gap;

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IVault vault_,
        bytes32 chainId_,
        address initialOwner,
        uint256 additionalGasUsed_,
        uint256 maxAllowableCallbackGasLimit_
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        vault = vault_;
        chainId = chainId_;

        _setAdditionalGasUsed(additionalGasUsed_);
        _setMaxAllowableCallbackGasLimit(maxAllowableCallbackGasLimit_);
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
     * @dev Sets the maximum gas used in calling targetAddr.process().
     * @param maxAllowableCallbackGasLimit_ The maximum allowable gas to be used when
     * calling the target contract.
     */
    function setMaxAllowableCallbackGasLimit(
        uint256 maxAllowableCallbackGasLimit_
    ) external onlyOwner {
        _setMaxAllowableCallbackGasLimit(maxAllowableCallbackGasLimit_);
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
        if (keccak256(bytes(packet.chainId)) != chainId) {
            revert InvalidChain(packet.chainId);
        }

        // verify signature.
        bool isValid = tssVerifier.verify(
            message,
            randomAddr,
            signature,
            tssMessage.sourceBlocktimestamp
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
            IDataConsumer(targetAddr).process{
                gas: maxAllowableCallbackGasLimit
            }(tssMessage)
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
    function minimumBalanceThreshold(
        uint64 tunnelId,
        address targetAddr
    ) public view override returns (uint256) {
        if (!isActive[tunnelId][targetAddr]) {
            return 0;
        }

        return _routerFee(additionalGasUsed + maxAllowableCallbackGasLimit);
    }

    function _isBalanceUnderThreshold(
        uint64 tunnelId,
        address addr
    ) internal view returns (bool) {
        uint256 remainingBalance = vault.balance(tunnelId, addr);
        uint256 minBalance = minimumBalanceThreshold(tunnelId, addr);
        return remainingBalance < minBalance;
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

    /// @dev Sets maxAllowableCallbackGasLimit and emit an event.
    function _setMaxAllowableCallbackGasLimit(
        uint256 maxAllowableCallbackGasLimit_
    ) internal {
        maxAllowableCallbackGasLimit = maxAllowableCallbackGasLimit_;
        emit MaxAllowableCallbackGasLimitSet(maxAllowableCallbackGasLimit);
    }

    /// @dev Sets additionalGasUsed and emit an event.
    function _setAdditionalGasUsed(uint256 additionalGasUsed_) internal {
        additionalGasUsed = additionalGasUsed_;
        emit AdditionalGasUsedSet(additionalGasUsed_);
    }

    receive() external payable {}
}
