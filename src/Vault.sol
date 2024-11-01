// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IVault.sol";
import "./interfaces/ITunnelRouter.sol";

contract Vault is Initializable, Ownable2StepUpgradeable, IVault {
    mapping(uint64 => mapping(address => uint)) public balance; // tunnelId => account => amount.

    uint256 public minimumActiveBalance;
    address public tunnelRouter;

    uint[50] __gap;

    modifier onlyTunnelRouter() {
        if (msg.sender != tunnelRouter) {
            revert UnauthorizedTunnelRouter();
        }
        _;
    }

    function initialize(
        address initialOwner,
        address tunnelRouter_
    ) public initializer {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();

        _setTunnelRouter(tunnelRouter_);
    }

    /**
     * @dev set the tunnel router contract address
     * @param tunnelRouter_ the tunnel router contract address
     */
    function setTunnelRouter(address tunnelRouter_) external onlyOwner {
        _setTunnelRouter(tunnelRouter_);
    }

    /**
     * @dev See {IVault-deposit}.
     */
    function deposit(uint64 tunnelId, address account) external payable {
        balance[tunnelId][account] += msg.value;
        emit Deposited(tunnelId, msg.sender, account, msg.value);
    }

    /**
     * @dev See {IVault-withdraw}.
     */
    function withdraw(uint64 tunnelId, uint256 amount) external {
        if (_isRemainingBalanceUnderThreshold(tunnelId, msg.sender, amount)) {
            revert InsufficientRemainingBalance();
        }

        _withdraw(tunnelId, msg.sender, msg.sender, amount);
    }

    /**
     * @dev See {IVault-withdrawAll}.
     */
    function withdrawAll(uint64 tunnelId) external {
        uint256 amount = balance[tunnelId][msg.sender];

        if (_isRemainingBalanceUnderThreshold(tunnelId, msg.sender, amount)) {
            revert InsufficientRemainingBalance();
        }

        _withdraw(tunnelId, msg.sender, msg.sender, amount);
    }

    /**
     * @dev See {IVault-collectFee}.
     */
    function collectFee(
        uint64 tunnelId,
        address account,
        uint256 amount
    ) public onlyTunnelRouter {
        _withdraw(tunnelId, account, tunnelRouter, amount);
    }

    function _isRemainingBalanceUnderThreshold(
        uint64 tunnelId,
        address account,
        uint256 amount
    ) internal view returns (bool) {
        uint256 minBalance;
        ITunnelRouter router = ITunnelRouter(tunnelRouter);

        if (router.isActive(tunnelId, account)) {
            minBalance = router.minimumBalanceThreshold();
        }

        uint256 current = balance[tunnelId][account];
        return current < minBalance + amount;
    }

    function _withdraw(
        uint64 tunnelId,
        address account,
        address to,
        uint256 amount
    ) internal {
        balance[tunnelId][account] -= amount;

        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) {
            revert TokenTransferFailed(to);
        }

        emit Withdrawn(tunnelId, account, to, amount);
    }

    function _setTunnelRouter(address tunnelRouter_) internal {
        tunnelRouter = tunnelRouter_;
        emit TunnelRouterSet(tunnelRouter_);
    }

    receive() external payable {}
}
