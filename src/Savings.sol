// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICoopVault} from "./interfaces/ICoopVault.sol";
import {ISavings} from "./interfaces/ISavings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Savings is ISavings, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ICoopVault private immutable i_coopVault;
    IERC20 private immutable i_stablecoin;

    mapping(address => SavingsAccount) private s_accounts;

    uint256 private s_totalSavings;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address stableCoin, address coopVaultAddress) {
        if (stableCoin == address(0)) revert InvalidAddress();
        if (coopVaultAddress == address(0)) revert InvalidAddress();

        i_stablecoin = IERC20(stableCoin);
        i_coopVault = ICoopVault(coopVaultAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavings
    function deposit(uint256 amount) external override nonReentrant {
        if (amount == 0) revert CannotBeZero();

        if (!i_coopVault.isActiveMember(msg.sender)) {
            revert NotMember();
        }

        i_stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        SavingsAccount storage account = s_accounts[msg.sender];

        account.balance += amount;
        account.totalDeposited += amount;

        s_totalSavings += amount;

        emit Deposit(msg.sender, amount, account.balance);
    }

    /// @inheritdoc ISavings
    function withdraw(uint256 amount) external override nonReentrant {
        if (amount == 0) revert CannotBeZero();

        if (!i_coopVault.isMember(msg.sender)) {
            revert NotMember();
        }

        SavingsAccount storage account = s_accounts[msg.sender];

        if (amount > account.balance) {
            revert InsufficientBalance();
        }

        account.balance -= amount;
        account.totalWithdrawn += amount;

        s_totalSavings -= amount;

        i_stablecoin.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, account.balance);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISavings
    function balanceOf(address member) external view override returns (uint256) {
        return s_accounts[member].balance;
    }

    /// @inheritdoc ISavings
    function getSavingsAccount(address member) external view override returns (SavingsAccount memory) {
        return s_accounts[member];
    }

    /// @inheritdoc ISavings
    function totalSavings() external view override returns (uint256) {
        return s_totalSavings;
    }
}
