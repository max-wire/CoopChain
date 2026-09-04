// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISavings {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidAddress();
    error CannotBeZero();
    error NotMember();
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);

    event Withdraw(address indexed user, uint256 amount, uint256 newBalance);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct SavingsAccount {
        uint256 balance;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit stablecoins into savings.
    function deposit(uint256 amount) external;

    /// @notice Withdraw stablecoins from savings.
    function withdraw(uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current savings balance of a member.
    function balanceOf(address member) external view returns (uint256);

    /// @notice Returns the complete savings account details.
    function getSavingsAccount(address member) external view returns (SavingsAccount memory);

    /// @notice Returns the total savings held by the contract.
    function totalSavings() external view returns (uint256);
}
