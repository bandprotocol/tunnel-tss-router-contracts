// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IVault.sol";

contract Vault is Initializable, Ownable2StepUpgradeable, IVault {
    mapping(uint64 => mapping(address => uint)) public balance; // tunnelID => account => amount.

    uint256 public minimumActiveBalance;
    address public tunnelRouter;

    uint[50] __gap;

    event SetMinimumActiveBalance(uint256 minimumActiveBalance);
    event SetTunnelRouter(address tunnelRouter_);
    event Deposit(
        uint256 indexed tunnelID,
        address indexed account,
        uint256 amount
    );
    event Withdraw(
        uint256 indexed tunnelID,
        address indexed account,
        address to,
        uint256 amount
    );

    modifier onlyTunnelRouter() {
        require(msg.sender == tunnelRouter, "TunnelDepositor: !tunnelRouter");
        _;
    }

    function initialize(
        address initialOwner,
        uint256 minimumActiveBalance_,
        address tunnelRouter_
    ) public initializer {
        __Ownable_init(initialOwner);
        __Ownable2Step_init();

        _setMinimumActiveBalance(minimumActiveBalance_);
        _setTunnelRouter(tunnelRouter_);
    }

    /**
     * @dev set minimum active balance.
     * @param minimumActiveBalance_ the minimum balance that the account must have
     * to be considered as active
     */
    function setMinimumActiveBalance(
        uint256 minimumActiveBalance_
    ) external onlyOwner {
        _setMinimumActiveBalance(minimumActiveBalance_);
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
    function deposit(uint64 tunnelID, address account) external payable {
        balance[tunnelID][account] += msg.value;
        emit Deposit(tunnelID, account, msg.value);
    }

    /**
     * @dev See {IVault-withdraw}.
     */
    function withdraw(uint64 tunnelID, uint256 amount) external {
        uint256 _balance = balance[tunnelID][msg.sender];
        require(
            _balance >= amount + minimumActiveBalance,
            "TunnelDepositor: !balance"
        );

        _withdraw(tunnelID, msg.sender, msg.sender, amount);
    }

    /**
     * @dev See {IVault-withdrawAll}.
     */
    function withdrawAll(
        uint64 tunnelID,
        address account
    ) external onlyTunnelRouter {
        _withdraw(tunnelID, account, account, balance[tunnelID][account]);
    }

    /**
     * @dev See {IVault-collectFee}.
     */
    function collectFee(
        uint64 tunnelID,
        address account,
        uint256 amount
    ) public onlyTunnelRouter {
        _withdraw(tunnelID, account, tunnelRouter, amount);
    }

    /**
     * @dev See {IVault-isBalanceOverThreshold}.
     */
    function isBalanceOverThreshold(
        uint64 tunnelID,
        address account
    ) external view returns (bool) {
        return balance[tunnelID][account] >= minimumActiveBalance;
    }

    function _withdraw(
        uint64 tunnelID,
        address account,
        address to,
        uint256 amount
    ) internal {
        balance[tunnelID][account] -= amount;

        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "TunnelDepositor: !send");

        emit Withdraw(tunnelID, account, to, amount);
    }

    function _setMinimumActiveBalance(uint256 minimumActiveBalance_) internal {
        minimumActiveBalance = minimumActiveBalance_;
        emit SetMinimumActiveBalance(minimumActiveBalance_);
    }

    function _setTunnelRouter(address tunnelRouter_) internal {
        tunnelRouter = tunnelRouter_;
        emit SetTunnelRouter(tunnelRouter_);
    }

    receive() external payable {}
}
