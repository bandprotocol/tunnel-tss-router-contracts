// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../interfaces/IPacketConsumer.sol";
import "../interfaces/ITssVerifier.sol";
import "../interfaces/ITunnelRouter.sol";
import "../interfaces/IVault.sol";

import "../libraries/PacketDecoder.sol";
import "../libraries/Originator.sol";

import "./ErrorHandler.sol";
import "./L1RouterGasCalculator.sol";

abstract contract BaseTunnelRouter is
    PausableUpgradeable,
    AccessControlUpgradeable,
    ITunnelRouter,
    ErrorHandler,
    L1RouterGasCalculator
{
    using PacketDecoder for bytes;

    ITssVerifier public tssVerifier;
    IVault public vault;

    // The maximum gas limit can be used when calling the target contract.
    uint256 public callbackGasLimit;
    // The hash of the source chain ID.
    bytes32 public sourceChainIdHash;
    // The hash of the target chain ID (the chain id where the contract is deployed).
    bytes32 public targetChainIdHash;
    // Role identifier for accounts allowed to update gas fee.
    bytes32 public constant GAS_FEE_UPDATER_ROLE = keccak256("GAS_FEE_UPDATER_ROLE");

    mapping(bytes32 => TunnelDetail) public tunnelDetails; // originatorHash => TunnelDetail

    // A list of senders allowed to relay packets.
    mapping(address => bool) public isAllowed; // sender address => isAllowed

    uint256[49] __gap;

    modifier onlyWhitelisted() {
        if (!isAllowed[msg.sender]) {
            revert SenderNotWhitelisted(msg.sender);
        }
        _;
    }

    function __BaseRouter_init(
        ITssVerifier tssVerifier_,
        IVault vault_,
        address initialOwner,
        uint256 packedAdditionalGasFuncCoeffs,
        uint256 maxCalldataBytes_,
        uint256 callbackGasLimit_,
        bytes32 sourceChainIdHash_,
        bytes32 targetChainIdHash_
    ) internal onlyInitializing {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
        __Pausable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(GAS_FEE_UPDATER_ROLE, initialOwner);
        __L1RouterGasCalculator_init(
            packedAdditionalGasFuncCoeffs,
            maxCalldataBytes_
        ); // UPDATED

        tssVerifier = tssVerifier_;
        vault = vault_;
        sourceChainIdHash = sourceChainIdHash_;
        targetChainIdHash = targetChainIdHash_;

        _setCallbackGasLimit(callbackGasLimit_);
    }

    /**
     * @dev Sets the packedCoeffs being used in relaying message.
     * @param packedCoeffs The new additional gas used amount.
     */
    function setPackedAdditionalGasFuncCoeffs(
        uint256 packedCoeffs
    ) external onlyOwner {
        _setPackedAdditionalGasFuncCoeffs(packedCoeffs);
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
    ) external whenNotPaused onlyWhitelisted {
        PacketDecoder.TssMessage memory tssMessage = message.decodeTssMessage();
        PacketDecoder.Packet memory packet = tssMessage.packet;
        bytes32 originatorHash_ = tssMessage.originatorHash;

        // check if the message is valid.
        if (tssMessage.encoderType == PacketDecoder.EncoderType.Undefined) {
            revert UndefinedEncoderType();
        }

        // validate the activeness and sequence of the target contract.
        TunnelDetail memory tunnelDetail = tunnelDetails[originatorHash_];
        if (!tunnelDetail.isActive) {
            revert TunnelNotActive(originatorHash_);
        }

        if (tunnelDetail.sequence + 1 != packet.sequence) {
            revert InvalidSequence(tunnelDetail.sequence + 1, packet.sequence);
        }

        // update the sequence.
        tunnelDetails[originatorHash_].sequence = packet.sequence;

        // verify signature.
        bool isValid = tssVerifier.verify(
            keccak256(message),
            randomAddr,
            signature
        );
        if (!isValid) {
            revert InvalidSignature();
        }

        // forward the message to the target contract.
        uint256 beginGasleft = gasleft();
        (bool isSuccess, ) = _callWithCustomErrorHandling(
            tunnelDetail.targetAddr,
            callbackGasLimit,
            abi.encodeWithSelector(IPacketConsumer.process.selector, tssMessage)
        );
        uint256 targetGasUsed = beginGasleft - gasleft();

        emit MessageProcessed(originatorHash_, packet.sequence, isSuccess);

        // charge a fee from the target contract and send to caller.
        uint256 calldataSize;
        assembly {
            calldataSize := calldatasize()
        }
        uint256 fee = _routerFee(
            targetGasUsed + _additionalGasForCalldata(calldataSize)
        );
        vault.collectFee(originatorHash_, msg.sender, fee);

        // deactivate the target contract if the remaining balance is under the threshold.
        if (_isBalanceUnderThreshold(originatorHash_)) {
            _deactivate(originatorHash_);
        }
    }

    /**
     * @dev See {ITunnelRouter-activate}.
     */
    function activate(uint64 tunnelId, uint64 latestSeq) external payable {
        bytes32 originatorHash_ = originatorHash(tunnelId, msg.sender);
        if (tunnelDetails[originatorHash_].isActive) {
            revert TunnelAlreadyActive(originatorHash_);
        }

        vault.deposit{value: msg.value}(tunnelId, msg.sender);

        // cannot activate if the remaining balance is under the threshold.
        if (_isBalanceUnderThreshold(originatorHash_)) {
            revert InsufficientRemainingBalance(tunnelId, msg.sender);
        }

        tunnelDetails[originatorHash_] = TunnelDetail({
            isActive: true,
            sequence: latestSeq,
            tunnelId: tunnelId,
            targetAddr: msg.sender
        });

        emit Activated(originatorHash_, latestSeq);
    }

    /**
     * @dev See {ITunnelRouter-deactivate}.
     */
    function deactivate(uint64 tunnelId) external {
        bytes32 originatorHash_ = Originator.hash(
            sourceChainIdHash,
            tunnelId,
            targetChainIdHash,
            msg.sender
        );

        if (!tunnelDetails[originatorHash_].isActive) {
            revert TunnelNotActive(originatorHash_);
        }

        _deactivate(originatorHash_);
    }

    /**
     * @dev See {ITunnelRouter-minimumBalanceThreshold}.
     */
    function minimumBalanceThreshold() public view override returns (uint256) {
        return
            _routerFee(
                callbackGasLimit + _additionalGasForCalldata(maxCalldataBytes)
            );
    }

    /**
     * @dev See {ITunnelRouter-tunnelInfo}.
     */
    function tunnelInfo(
        uint64 tunnelId,
        address addr
    ) external view returns (TunnelInfo memory) {
        bytes32 originatorHash_ = Originator.hash(
            sourceChainIdHash,
            tunnelId,
            targetChainIdHash,
            addr
        );
        TunnelDetail memory tunnelDetail = tunnelDetails[originatorHash_];

        return
            TunnelInfo({
                isActive: tunnelDetail.isActive,
                latestSequence: tunnelDetail.sequence,
                balance: vault.getBalanceByOriginatorHash(originatorHash_),
                originatorHash: originatorHash_
            });
    }

    /**
     * @dev See {ITunnelRouter-originatorHash}.
     */
    function originatorHash(
        uint64 tunnelId,
        address addr
    ) public view returns (bytes32) {
        return
            Originator.hash(
                sourceChainIdHash,
                tunnelId,
                targetChainIdHash,
                addr
            );
    }

    /**
     * @dev Sets senders' address by given flag.
     */
    function setWhitelist(
        address[] memory senders,
        bool flag
    ) external onlyOwner {
        for (uint256 i = 0; i < senders.length; i++) {
            if (senders[i] == address(0)) {
                revert InvalidSenderAddress();
            }
            isAllowed[senders[i]] = flag;
            emit SetWhitelist(senders[i], flag);
        }
    }

    /**
     * @dev Register/Add a new custom error for the consumer.
     */
    function registerError(
        address target,
        string calldata fsigStr
    ) external onlyOwner {
        _registerError(target, fsigStr);
    }

    /**
     * @dev Unregister/Remove an existed custom error for the consumer.
     */
    function unregisterError(
        address target,
        string calldata fsigStr
    ) external onlyOwner {
        _unregisterError(target, fsigStr);
    }

    /**
     * @dev See {ITunnelRouter-isActive}.
     */
    function isActive(
        bytes32 originatorHash_
    ) public view override returns (bool) {
        return tunnelDetails[originatorHash_].isActive;
    }

    /**
     * @dev See {ITunnelRouter-sequence}.
     */
    function sequence(
        bytes32 originatorHash_
    ) public view override returns (uint64) {
        return tunnelDetails[originatorHash_].sequence;
    }

    /// @dev Checks if the remaining balance is lower than the threshold.
    function _isBalanceUnderThreshold(
        bytes32 originatorHash_
    ) internal view returns (bool) {
        uint256 remainingBalance = vault.getBalanceByOriginatorHash(
            originatorHash_
        );
        return remainingBalance < minimumBalanceThreshold();
    }

    /// @dev Deactivates the given originator hash.
    function _deactivate(bytes32 originatorHash_) internal {
        tunnelDetails[originatorHash_].isActive = false;
        emit Deactivated(
            originatorHash_,
            tunnelDetails[originatorHash_].sequence
        );
    }

    /// @dev Calculates the fee for the router.
    function _routerFee(
        uint256 gasUsed
    ) internal view virtual returns (uint256);

    /// @dev Sets callbackGasLimit and emit an event.
    function _setCallbackGasLimit(uint256 callbackGasLimit_) internal {
        callbackGasLimit = callbackGasLimit_;
        emit CallbackGasLimitSet(callbackGasLimit_);
    }

    /// @dev Grants `GAS_FEE_UPDATER_ROLE` to `accounts`
    function grantGasFeeUpdater(address[] calldata accounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _grantRole(GAS_FEE_UPDATER_ROLE, accounts[i]);
        }
    }

    /// @dev Revokes `GAS_FEE_UPDATER_ROLE` from  `accounts`
    function revokeGasFeeUpdater(address[] calldata accounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _revokeRole(GAS_FEE_UPDATER_ROLE, accounts[i]);
        }
    }
}
