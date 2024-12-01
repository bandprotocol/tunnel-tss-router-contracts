// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IVault.sol";
import "./interfaces/ITunnelRouter.sol";
import "./libraries/Address.sol";
import "./libraries/Originator.sol";

contract Vault is Initializable, Ownable2StepUpgradeable, IVault {
    address public tunnelRouter;
    bytes32 public sourceChainIdHash;
    bytes32 public targetChainIdHash;

    mapping(bytes32 => uint256) private _balance; // originatorHash => amount.

    uint256[50] internal __gap;

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    function initialize(address initialOwner, address tunnelRouter_) public initializer {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();

        // Set the tunnel router contract address if it is provided.
        if (tunnelRouter_ != address(0)) {
            _setTunnelRouter(tunnelRouter_);
        }
    }

    /**
     * @dev Sets the tunnel router contract address
     * @param tunnelRouter_ The tunnel router contract address
     */
    function setTunnelRouter(address tunnelRouter_) external onlyOwner {
        _setTunnelRouter(tunnelRouter_);
    }

    /**
     * @dev See {IVault-deposit}.
     */
    function deposit(uint64 tunnelId, address to) external payable {
        bytes32 originatorHash = Originator.hash(sourceChainIdHash, targetChainIdHash, tunnelId, to);
        _balance[originatorHash] += msg.value;
        emit Deposited(originatorHash, msg.sender, msg.value);
    }

    /**
     * @dev See {IVault-withdraw}.
     */
    function withdraw(uint64 tunnelId, address to, uint256 amount) external {
        bytes32 originatorHash = Originator.hash(sourceChainIdHash, targetChainIdHash, tunnelId, msg.sender);

        ITunnelRouter router = ITunnelRouter(tunnelRouter);
        uint256 threshold;
        if (router.isActive(originatorHash)) {
            threshold = router.minimumBalanceThreshold();
        }

        if (threshold + amount > _balance[originatorHash]) {
            revert WithdrawnAmountExceedsThreshold();
        }

        _withdraw(originatorHash, to, amount);
    }

    /**
     * @dev See {IVault-withdrawAll}.
     */
    function withdrawAll(uint64 tunnelId, address to) external {
        bytes32 originatorHash = Originator.hash(sourceChainIdHash, targetChainIdHash, tunnelId, msg.sender);
        uint256 amount = _balance[originatorHash];

        ITunnelRouter router = ITunnelRouter(tunnelRouter);
        if (router.isActive(originatorHash)) {
            revert TunnelIsActive();
        }

        _withdraw(originatorHash, to, amount);
    }

    /**
     * @dev See {IVault-collectFee}.
     */
    function collectFee(bytes32 originatorHash, address to, uint256 amount) public onlyTunnelRouter {
        _withdraw(originatorHash, to, amount);
    }

    /**
     * @dev See {IVault-balance}.
     */
    function balance(uint64 tunnelId, address account) external view returns (uint256) {
        return _balance[Originator.hash(sourceChainIdHash, targetChainIdHash, tunnelId, account)];
    }

    /**
     * @dev See {IVault-getBalanceByOriginatorHash}.
     */
    function getBalanceByOriginatorHash(bytes32 originatorHash) external view returns (uint256) {
        return _balance[originatorHash];
    }

    function _withdraw(bytes32 originatorHash, address to, uint256 amount) internal {
        _balance[originatorHash] -= amount;
        (bool ok,) = payable(to).call{value: amount}("");
        if (!ok) {
            revert TokenTransferFailed(to);
        }

        emit Withdrawn(originatorHash, to, amount);
    }

    function _setTunnelRouter(address tunnelRouter_) internal {
        sourceChainIdHash = ITunnelRouter(tunnelRouter_).sourceChainIdHash();
        targetChainIdHash = ITunnelRouter(tunnelRouter_).targetChainIdHash();
        tunnelRouter = tunnelRouter_;
        emit TunnelRouterSet(tunnelRouter_);
    }

    receive() external payable {}
}
