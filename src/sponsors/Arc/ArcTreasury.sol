// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IArcTreasury} from "./interfaces/IArcTreasury.sol";

/**
 * @title ArcTreasury
 * @author Maxwell Wire
 * @notice USDC treasury for CoopChain deployed on Arc Testnet.
 *
 * @dev
 * This contract provides the USDC settlement layer for CoopChain.
 *
 * The treasury:
 * - accepts USDC from any address;
 * - allows the administrator to authorize treasury operators;
 * - allows the administrator and authorized operators to release USDC;
 * - allows only the administrator to withdraw USDC;
 * - does not mint USDC;
 * - does not custody investment tokens;
 * - does not execute investment purchases.
 *
 * Authorized operators are intended to represent trusted CoopChain
 * financial modules such as LoanEngine and InvestmentPool.
 *
 * USDC on Arc Testnet:
 * 0x3600000000000000000000000000000000000000
 */
contract ArcTreasury is IArcTreasury {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice USDC contract deployed on Arc Testnet.
    address public constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address authorized to manage the treasury.
    address private immutable i_admin;

    /// @notice USDC token held by this treasury.
    IERC20 private immutable i_usdc;

    /// @notice Addresses authorized to release USDC from the treasury.
    mapping(address => bool) private s_operators;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the Arc treasury.
     * @dev The deployer becomes the treasury administrator.
     */
    constructor() {
        i_admin = msg.sender;
        i_usdc = IERC20(ARC_TESTNET_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts an operation to the treasury administrator.
     */
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Unauthorized();
        }

        _;
    }

    /**
     * @notice Restricts an operation to the administrator or an
     *         authorized treasury operator.
     *
     * @dev
     * The administrator always has operator-level permissions.
     * Authorized operators may release USDC but cannot withdraw
     * treasury funds.
     */
    modifier onlyOperator() {
        if (msg.sender != i_admin && !s_operators[msg.sender]) {
            revert Unauthorized();
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArcTreasury
     */
    function fund(uint256 amount) external {
        if (amount == 0) {
            revert InvalidAmount();
        }

        i_usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit TreasuryFunded(msg.sender, amount);
    }

    /**
     * @inheritdoc IArcTreasury
     */
    function release(address to, uint256 amount) external onlyOperator {
        _validateTransfer(to, amount);

        uint256 balance = i_usdc.balanceOf(address(this));

        if (amount > balance) {
            revert InsufficientBalance();
        }

        i_usdc.safeTransfer(to, amount);

        emit TreasuryReleased(to, amount);
    }

    /**
     * @inheritdoc IArcTreasury
     */
    function withdraw(address to, uint256 amount) external onlyAdmin {
        _validateTransfer(to, amount);

        uint256 balance = i_usdc.balanceOf(address(this));

        if (amount > balance) {
            revert InsufficientBalance();
        }

        i_usdc.safeTransfer(to, amount);

        emit TreasuryWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArcTreasury
     */
    function setOperatorAuthorization(address operator, bool authorized) external onlyAdmin {
        if (operator == address(0)) {
            revert InvalidAddress();
        }

        s_operators[operator] = authorized;

        emit OperatorAuthorizationUpdated(operator, authorized);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArcTreasury
     */
    function getUSDC() external view returns (address) {
        return address(i_usdc);
    }

    /**
     * @inheritdoc IArcTreasury
     */
    function getAdmin() external view returns (address) {
        return i_admin;
    }

    /**
     * @inheritdoc IArcTreasury
     */
    function getBalance() external view returns (uint256) {
        return i_usdc.balanceOf(address(this));
    }

    /**
     * @inheritdoc IArcTreasury
     */
    function isOperatorAuthorized(address operator) external view returns (bool) {
        return s_operators[operator];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates a USDC transfer.
     * @param to Address receiving the USDC.
     * @param amount Amount of USDC being transferred.
     */
    function _validateTransfer(address to, uint256 amount) internal pure {
        if (to == address(0)) {
            revert InvalidAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }
    }
}
