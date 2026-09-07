// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IArcTreasury
 * @author Maxwell Wire
 * @notice Interface for the CoopChain USDC treasury on Arc Testnet.
 *
 * @dev
 * The treasury accepts USDC deposits from any address.
 *
 * The administrator can:
 * - authorize and revoke treasury operators;
 * - release USDC;
 * - withdraw USDC.
 *
 * Authorized operators can:
 * - release USDC for approved CoopChain financial operations.
 *
 * Operators cannot withdraw treasury funds.
 */
interface IArcTreasury {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when a transfer recipient or operator address
     *         is the zero address.
     */
    error InvalidAddress();

    /**
     * @notice Thrown when a zero or otherwise invalid amount is provided.
     */
    error InvalidAmount();

    /**
     * @notice Thrown when a caller does not have permission to perform
     *         the requested operation.
     */
    error Unauthorized();

    /**
     * @notice Thrown when the treasury does not have sufficient USDC
     *         balance to complete a transfer.
     */
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when USDC is deposited into the treasury.
     * @param funder Address that funded the treasury.
     * @param amount Amount of USDC deposited.
     */
    event TreasuryFunded(address indexed funder, uint256 amount);

    /**
     * @notice Emitted when USDC is released from the treasury.
     * @param to Address receiving the released USDC.
     * @param amount Amount of USDC released.
     */
    event TreasuryReleased(address indexed to, uint256 amount);

    /**
     * @notice Emitted when the administrator withdraws USDC from
     *         the treasury.
     * @param to Address receiving the withdrawn USDC.
     * @param amount Amount of USDC withdrawn.
     */
    event TreasuryWithdrawn(address indexed to, uint256 amount);

    /**
     * @notice Emitted when the authorization status of a treasury
     *         operator is updated.
     * @param operator Address whose authorization status changed.
     * @param authorized Whether the operator is authorized to release funds.
     */
    event OperatorAuthorizationUpdated(address indexed operator, bool authorized);

    /*//////////////////////////////////////////////////////////////
                        TREASURY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits USDC into the treasury.
     * @param amount Amount of USDC to deposit.
     *
     * @dev
     * Any address may fund the treasury.
     *
     * The caller must approve the treasury to spend the specified
     * amount of USDC before calling this function.
     */
    function fund(uint256 amount) external;

    /**
     * @notice Releases USDC from the treasury to a recipient.
     * @param to Address receiving the released USDC.
     * @param amount Amount of USDC to release.
     *
     * @dev
     * The treasury administrator and authorized operators may call
     * this function.
     *
     * Authorized operators are intended to represent CoopChain
     * financial components such as LoanEngine and InvestmentPool.
     *
     * Unlike `withdraw`, this function is intended for controlled
     * financial operations rather than administrative treasury
     * withdrawals.
     */
    function release(address to, uint256 amount) external;

    /**
     * @notice Withdraws USDC from the treasury to a recipient.
     * @param to Address receiving the withdrawn USDC.
     * @param amount Amount of USDC to withdraw.
     *
     * @dev
     * Restricted exclusively to the treasury administrator.
     *
     * Authorized operators cannot call this function.
     */
    function withdraw(address to, uint256 amount) external;

    /**
     * @notice Updates the authorization status of a treasury operator.
     * @param operator Address whose authorization status will be updated.
     * @param authorized Whether the operator should be authorized to
     *                   release treasury funds.
     *
     * @dev
     * Restricted exclusively to the treasury administrator.
     *
     * Setting `authorized` to true grants the operator permission to
     * call `release()`.
     *
     * Setting `authorized` to false revokes that permission.
     */
    function setOperatorAuthorization(address operator, bool authorized) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the USDC token held by the treasury.
     * @return The USDC token contract address.
     */
    function getUSDC() external view returns (address);

    /**
     * @notice Returns the address of the treasury administrator.
     * @return The administrator address.
     */
    function getAdmin() external view returns (address);

    /**
     * @notice Returns the current USDC balance of the treasury.
     * @return The amount of USDC held by the treasury.
     */
    function getBalance() external view returns (uint256);

    /**
     * @notice Returns whether an address is an authorized treasury operator.
     * @param operator Address to check.
     * @return True if the address is authorized to release funds,
     *         otherwise false.
     */
    function isOperatorAuthorized(address operator) external view returns (bool);
}
