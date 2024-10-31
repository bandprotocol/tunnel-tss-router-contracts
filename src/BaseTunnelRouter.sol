// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./interfaces/IDataConsumer.sol";
import "./interfaces/ITssVerifier.sol";
import "./interfaces/ITunnelRouter.sol";
import "./interfaces/IVault.sol";

import "./libraries/PacketDecoder.sol";
import "./libraries/StringAddress.sol";

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

    // The ID of the chain. Used to validate messages received from the tunnel.
    bytes32 public chainID;
    // Additional gas estimated for relaying the message;
    // does not include the gas cost for executing the target contract.
    uint256 public additionalGasUsed;
    // The maximum allowable gas to be used when calling the target contract.
    uint256 public maxAllowableCallbackGasLimit;

    mapping(uint64 => mapping(address => bool)) public isActive; // tunnelID => targetAddr => isActive
    mapping(uint64 => mapping(address => uint64)) public sequence; // tunnelID => targetAddr => sequence

    uint[50] __gap;

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IVault vault_,
        bytes32 chainID_,
        address initialOwner,
        uint256 additionalGasUsed_,
        uint256 maxAllowableCallbackGasLimit_
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        vault = vault_;
        chainID = chainID_;
        additionalGasUsed = additionalGasUsed_;
        maxAllowableCallbackGasLimit = maxAllowableCallbackGasLimit_;
    }

    /**
     * @dev Set the additionalGasUsed being used in relaying message.
     * @param additionalGasUsed_ The new additional gas used amount.
     */
    function setAdditionalGasUsed(
        uint256 additionalGasUsed_
    ) external onlyOwner {
        additionalGasUsed = additionalGasUsed_;
        emit SetAdditionalGas(additionalGasUsed_);
    }

    /**
     * @dev Set the maximum gas used in calling targetAddr.process().
     * @param maxAllowableCallbackGasLimit_  The maximum allowable gas to be used when
     * calling the target contract.
     */
    function setMaxAllowableCallbackGasLimit(
        uint256 maxAllowableCallbackGasLimit_
    ) external onlyOwner {
        maxAllowableCallbackGasLimit = maxAllowableCallbackGasLimit_;
        emit SetMaxAllowableCallbackGasLimit(maxAllowableCallbackGasLimit);
    }

    /**
     * @dev pause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause the contract.
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
        if (!isActive[packet.tunnelID][targetAddr]) {
            revert Inactive(targetAddr);
        }
        if (sequence[packet.tunnelID][targetAddr] + 1 != packet.sequence) {
            revert InvalidSequence(
                sequence[packet.tunnelID][targetAddr] + 1,
                packet.sequence
            );
        }
        if (keccak256(bytes(packet.chainID)) != chainID) {
            revert InvalidChain(packet.chainID);
        }

        // verify signature.
        bool isValid = tssVerifier.verify(message, randomAddr, signature);
        if (!isValid) {
            revert InvalidSignature();
        }

        // update the sequence.
        sequence[packet.tunnelID][targetAddr] = packet.sequence;

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
        emit ProcessMessage(
            packet.tunnelID,
            targetAddr,
            packet.sequence,
            isReverted
        );

        // charge a fee from the target contract.
        uint256 fee = _routerFee(gasLeft - gasleft() + additionalGasUsed);
        vault.collectFee(packet.tunnelID, targetAddr, fee);

        if (!vault.isBalanceOverThreshold(packet.tunnelID, targetAddr)) {
            _deactivate(packet.tunnelID, targetAddr);
        }

        (bool ok, ) = payable(msg.sender).call{value: fee}("");
        if (!ok) {
            revert FailSendTokens(msg.sender);
        }
    }

    /**
     * @dev See {ITunnelRouter-activate}.
     */
    function activate(uint64 tunnelID, uint64 latestSeq) external payable {
        if (isActive[tunnelID][msg.sender]) {
            revert Active(msg.sender);
        }

        vault.deposit{value: msg.value}(tunnelID, msg.sender);
        if (!vault.isBalanceOverThreshold(tunnelID, msg.sender)) {
            revert InsufficientBalance(tunnelID, msg.sender);
        }

        isActive[tunnelID][msg.sender] = true;
        sequence[tunnelID][msg.sender] = latestSeq;
        emit Activate(tunnelID, msg.sender, latestSeq);
    }

    /**
     * @dev See {ITunnelRouter-deactivate}.
     */
    function deactivate(uint64 tunnelID) external {
        if (!isActive[tunnelID][msg.sender]) {
            revert Inactive(msg.sender);
        }

        _deactivate(tunnelID, msg.sender);

        // withdraw the remaining balance from vault contract.
        vault.withdrawAll(tunnelID, msg.sender);
    }

    /**
     * @dev See {ITunnelRouter-deposit}.
     */
    function deposit(uint64 tunnelID, address account) external payable {
        vault.deposit{value: msg.value}(tunnelID, account);
    }

    /// @dev deactivate the (contract address, tunnelID).
    function _deactivate(uint64 tunnelID, address addr) internal {
        isActive[tunnelID][addr] = false;
        emit Deactivate(tunnelID, addr, sequence[tunnelID][addr]);
    }

    /// @dev calculate the fee for the router.
    function _routerFee(uint256 gasUsed) internal view virtual returns (uint) {
        gasUsed; // Shh

        return 0;
    }

    receive() external payable {}
}
