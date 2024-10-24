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

    // the ID of the chain, will be used in validating message from the tunnel.
    bytes32 public chainID;
    // estimated additional gas used in relaying message, excluding the gas cost for calling the target contract.
    uint256 public additionalGas;
    // the maximum gas used in calling the target contract.
    uint256 public maxGasUsedProcess;

    mapping(uint64 => mapping(address => bool)) public isActive; // tunnelID => targetAddr => isActive
    mapping(uint64 => mapping(address => uint64)) public sequence; // tunnelID => targetAddr => sequence

    uint[50] __gap;

    event SetMaxGasUsedProcess(uint256 maxGasUsedProcess);
    event SetAdditionalGas(uint256 additionalGas);
    event ProcessMessage(
        uint64 indexed tunnelID,
        address indexed targetAddr,
        uint64 indexed sequence,
        bool isReverted
    );
    event Activate(
        uint64 indexed tunnelID,
        address indexed targetAddr,
        uint64 latestNonce
    );
    event Deactivate(
        uint64 indexed tunnelID,
        address indexed targetAddr,
        uint64 latestNonce
    );

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IVault vault_,
        bytes32 chainID_,
        address initialOwner,
        uint256 additionalGas_,
        uint256 maxGasUsedProcess_
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();

        tssVerifier = tssVerifier_;
        vault = vault_;
        chainID = chainID_;
        additionalGas = additionalGas_;
        maxGasUsedProcess = maxGasUsedProcess_;
    }

    /**
     * @dev Set the additionalGas being used in relaying message.
     * @param additionalGas_ The new additional gas amount.
     */
    function setAdditionalGas(uint256 additionalGas_) external onlyOwner {
        additionalGas = additionalGas_;
        emit SetAdditionalGas(additionalGas_);
    }

    /**
     * @dev Set the maximum gas used in calling targetAddr.process().
     * @param maxGasUsedProcess_ The maximum gas used in calling targetAddr.process().
     */
    function setMaxGasUsedProcess(
        uint256 maxGasUsedProcess_
    ) external onlyOwner {
        maxGasUsedProcess = maxGasUsedProcess_;
        emit SetMaxGasUsedProcess(maxGasUsedProcess);
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
        address rAddr,
        uint256 signature
    ) external whenNotPaused {
        PacketDecoder.TssMessage memory tssMessage = message.decodeTssMessage();
        PacketDecoder.Packet memory packet = tssMessage.packet;
        address targetAddr = packet.targetAddr.toAddress();

        // check if a message is valid.
        require(isActive[packet.tunnelID][targetAddr], "TunnelRouter: !active");
        require(
            sequence[packet.tunnelID][targetAddr] + 1 == packet.sequence,
            "TunnelRouter: !sequence"
        );
        require(
            keccak256(bytes(packet.chainID)) == chainID,
            "TunnelRouter: !chainID"
        );

        // verify signature.
        bool success = tssVerifier.verify(message, rAddr, signature);
        require(success, "TunnelRouter: !verify");

        // update the sequence.
        sequence[packet.tunnelID][targetAddr] = packet.sequence;

        // forward the message to the target contract.
        uint256 gasLeft = gasleft();
        bool isReverted = false;
        try
            IDataConsumer(targetAddr).process{gas: maxGasUsedProcess}(message)
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
        uint256 fee = _routerFee(gasLeft - gasleft() + additionalGas);
        vault.collectFee(packet.tunnelID, targetAddr, fee);

        if (!vault.isBalanceOverThreshold(packet.tunnelID, targetAddr)) {
            _deactivate(packet.tunnelID, targetAddr);
        }

        (bool ok, ) = payable(msg.sender).call{value: fee}("");
        require(ok, "TunnelRouter: Fail to send fee");
    }

    /**
     * @dev See {ITunnelRouter-activate}.
     */
    function activate(uint64 tunnelID, uint64 latestSeq) external payable {
        require(!isActive[tunnelID][msg.sender], "TunnelRouter: !inactive");

        vault.deposit{value: msg.value}(tunnelID, msg.sender);

        require(
            vault.isBalanceOverThreshold(tunnelID, msg.sender),
            "TunnelRouter: !threshold"
        );

        isActive[tunnelID][msg.sender] = true;
        sequence[tunnelID][msg.sender] = latestSeq;
        emit Activate(tunnelID, msg.sender, latestSeq);
    }

    /**
     * @dev See {ITunnelRouter-deactivate}.
     */
    function deactivate(uint64 tunnelID) external {
        require(isActive[tunnelID][msg.sender], "TunnelRouter: !active");
        _deactivate(tunnelID, msg.sender);

        // withdraw the remaining balance from vault contract.
        vault.withdrawAll(tunnelID, msg.sender);
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
