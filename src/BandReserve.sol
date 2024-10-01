// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IBandReserve.sol";

contract BandReserve is IBandReserve, Initializable, Ownable2StepUpgradeable {
    mapping(address => bool) public whitelist;
    mapping(address => uint) public debt;
    mapping(address => bool) public bannedDebtor;

    uint[49] __gap;

    event SetBannedDebtor(address indexed addr, bool isBanned);
    event SetWhitelist(address indexed addr, bool isBanned);
    event BorrowOnBehalf(address indexed debtor, uint amount);
    event Repay(address indexed debtor, uint amount);

    modifier onlyWhitelist() {
        require(
            whitelist[msg.sender],
            "BandReserve: caller is not the whitelist"
        );
        _;
    }

    function initialize() public initializer {
        __Ownable2Step_init();
    }

    /// @dev set whitelist caller for calling borrowOnBehalf.
    /// @param addresses list of caller addresses.
    /// @param isWhitelist true to set whitelist, false to remove from the whitelist.
    function setWhitelist(
        address[] memory addresses,
        bool isWhitelist
    ) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = isWhitelist;
            emit SetWhitelist(addresses[i], isWhitelist);
        }
    }

    /// @dev set banned debtor.
    /// @param addresses list of debtor addresses.
    /// @param isBanned true to set the debtor as banned, false to remove from the banned list.
    function setBannedDebtor(
        address[] memory addresses,
        bool isBanned
    ) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            bannedDebtor[addresses[i]] = isBanned;
            emit SetBannedDebtor(addresses[i], isBanned);
        }
    }

    /// @dev borrow on behalf of the debtor.
    /// @param amount amount of eth to borrow.
    /// @param debtor address of the debtor.
    function borrowOnBehalf(
        uint amount,
        address debtor
    ) external onlyWhitelist {
        require(!bannedDebtor[debtor], "BandReserve: debtor is banned");
        debt[debtor] += amount;

        (bool ok, ) = (msg.sender).call{value: amount}("");
        require(ok, "BandReserve: Fail to send eth");

        emit BorrowOnBehalf(debtor, amount);
    }

    /// @dev repay the debt.
    /// @param debtor address of the debtor.
    function repay(address debtor) external payable {
        if (msg.value >= debt[debtor]) {
            debt[debtor] = 0;
        } else {
            debt[debtor] -= msg.value;
        }

        emit Repay(debtor, msg.value);
    }

    receive() external payable {}
}
