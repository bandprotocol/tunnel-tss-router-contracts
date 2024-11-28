// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IVault.sol";
import "./interfaces/ITunnelRouter.sol";
import "./libraries/Address.sol";

contract Vault is Initializable, Ownable2StepUpgradeable, IVault {
    bytes4 public ORIGINATOR_HASH_PREFIX;
    bytes32 public SOURCE_CHAIN_ID_HASH;

    mapping(bytes32 => uint) private _balance; // originatorHash => amount.

    address public tunnelRouter;

    uint[50] internal __gap;

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    function initialize(
        address initialOwner,
        address tunnelRouter_,
        bytes4 originatorHashPrefix,
        string calldata sourceChainId
    ) public initializer {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();

        _setTunnelRouter(tunnelRouter_);

        ORIGINATOR_HASH_PREFIX = originatorHashPrefix;
        SOURCE_CHAIN_ID_HASH = keccak256(bytes(sourceChainId));
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
        bytes32 originatorHash = _originatorHash(tunnelId, to);
        _balance[originatorHash] += msg.value;
        emit Deposited(originatorHash, msg.sender, msg.value);
    }

    /**
     * @dev See {IVault-withdraw}.
     */
    function withdraw(uint64 tunnelId, address to, uint256 amount) external {
        ITunnelRouter router = ITunnelRouter(tunnelRouter);
        uint256 threshold;
        if (router.isActive(tunnelId, msg.sender)) {
            threshold = router.minimumBalanceThreshold();
        }

        bytes32 originatorHash = _originatorHash(tunnelId, msg.sender);
        if (threshold > _balance[originatorHash] - amount) {
            revert WithdrawnAmountExceedsThreshold();
        }

        _withdraw(originatorHash, to,amount);
    }

    /**
     * @dev See {IVault-withdrawAll}.
     */
    function withdrawAll(uint64 tunnelId, address to) external {
        bytes32 originatorHash = _originatorHash(tunnelId, msg.sender);
        uint256 amount = _balance[originatorHash];

        ITunnelRouter router = ITunnelRouter(tunnelRouter);
        if (router.isActive(tunnelId, msg.sender)) {
            revert TunnelIsActive();
        }

        _withdraw(originatorHash,to, amount);
    }

    /**
     * @dev See {IVault-collectFee}.
     */
    function collectFee(uint64 tunnelId, address account, uint256 amount) public onlyTunnelRouter {
        _withdraw(_originatorHash(tunnelId, account), tunnelRouter, amount);
    }

    function balance(uint64 tunnelId, address account) external view returns (uint256) {
        return _balance[_originatorHash(tunnelId, account)];
    }

    function _originatorHash(
        uint64 tunnelId,
        address account
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                ORIGINATOR_HASH_PREFIX,
                SOURCE_CHAIN_ID_HASH,
                bytes8(tunnelId),
                block.chainid,
                keccak256(bytes(Address.toChecksumString(account)))
            )
        );
    }

    function _withdraw(
        bytes32 originatorHash,
        address to,
        uint256 amount
    ) internal {
        _balance[originatorHash] -= amount;
        (bool ok,) = payable(to).call{value: amount}("");
        if (!ok) {
            revert TokenTransferFailed(to);
        }

        emit Withdrawn(originatorHash, to, amount);
    }

    function _setTunnelRouter(address tunnelRouter_) internal {
        tunnelRouter = tunnelRouter_;
        emit TunnelRouterSet(tunnelRouter_);
    }

    receive() external payable {}
}
