// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IInvestmentPool
 * @author Maxwell Wire
 * @notice Interface for managing cooperative investment purchases, redemptions,
 *         pool funding, and withdrawals.
 * @dev
 * The InvestmentPool acts as the settlement layer between investors,
 * stablecoin funds, investment products, and investment tokens.
 *
 * It is responsible for:
 * - accepting stablecoin investments
 * - minting or distributing investment tokens
 * - redeeming investment tokens for stablecoin
 * - receiving liquidity from authorized funders
 * - processing authorized pool withdrawals
 * - calculating investment and redemption values
 *
 * Investment registration, investment metadata, and investment status are
 * managed by the InvestmentRegistry.
 */
interface IInvestmentPool {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided where a valid address is required.
    error InvalidAddress();

    /// @notice Thrown when a zero or otherwise invalid amount is provided.
    error InvalidAmount();

    /// @notice Thrown when the specified investment does not exist.
    error InvestmentNotFound();

    /// @notice Thrown when the specified investment is not currently active.
    error InvestmentInactive();

    /// @notice Thrown when the investment token is invalid or not configured.
    error InvalidToken();

    /// @notice Thrown when the pool does not have sufficient stablecoin liquidity.
    error InsufficientPoolBalance();

    /// @notice Thrown when an investor does not have sufficient investment tokens.
    error InsufficientTokenBalance();

    /// @notice Thrown when the caller is not authorized to perform the operation.
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when an investor purchases investment tokens.
     * @param investor Address of the investor who made the purchase.
     * @param investmentId Unique identifier of the investment product.
     * @param usdcAmount Amount of stablecoin used for the investment.
     * @param tokenAmount Amount of investment tokens received by the investor.
     */
    event InvestmentPurchased(
        address indexed investor, uint256 indexed investmentId, uint256 usdcAmount, uint256 tokenAmount
    );

    /**
     * @notice Emitted when an investor redeems investment tokens.
     * @param investor Address of the investor who redeemed the tokens.
     * @param investmentId Unique identifier of the investment product.
     * @param tokenAmount Amount of investment tokens redeemed.
     * @param usdcAmount Amount of stablecoin returned to the investor.
     */
    event InvestmentRedeemed(
        address indexed investor, uint256 indexed investmentId, uint256 tokenAmount, uint256 usdcAmount
    );

    /**
     * @notice Emitted when stablecoin liquidity is added to the investment pool.
     * @param funder Address that supplied the stablecoin liquidity.
     * @param amount Amount of stablecoin added to the pool.
     */
    event PoolFunded(address indexed funder, uint256 amount);

    /**
     * @notice Emitted when stablecoin liquidity is withdrawn from the pool.
     * @param recipient Address receiving the withdrawn stablecoin.
     * @param amount Amount of stablecoin withdrawn.
     */
    event PoolWithdrawn(address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Purchases units of a registered investment product.
     * @dev
     * The investment must exist and be active. The caller provides stablecoin
     * and receives the corresponding amount of investment tokens.
     *
     * @param investmentId Unique identifier of the investment product.
     * @param usdcAmount Amount of stablecoin to invest.
     * @return tokenAmount Amount of investment tokens received.
     */
    function invest(uint256 investmentId, uint256 usdcAmount) external returns (uint256 tokenAmount);

    /**
     * @notice Redeems investment tokens for stablecoin.
     * @dev
     * The investment must exist and the caller must have sufficient investment
     * tokens. The pool must also have sufficient stablecoin liquidity to
     * complete the redemption.
     *
     * @param investmentId Unique identifier of the investment product.
     * @param tokenAmount Amount of investment tokens to redeem.
     * @return usdcAmount Amount of stablecoin returned to the investor.
     */
    function redeem(uint256 investmentId, uint256 tokenAmount) external returns (uint256 usdcAmount);

    /**
     * @notice Adds stablecoin liquidity to the investment pool.
     * @dev
     * Funding increases the stablecoin liquidity available for investment
     * redemptions and other pool operations.
     *
     * @param amount Amount of stablecoin to add to the pool.
     */
    function fund(uint256 amount) external;

    /**
     * @notice Withdraws stablecoin from the investment pool.
     * @dev
     * The caller must have the required authorization and the pool must have
     * sufficient available liquidity.
     *
     * @param recipient Address receiving the withdrawn stablecoin.
     * @param amount Amount of stablecoin to withdraw.
     */
    function withdraw(address recipient, uint256 amount) external;

    /**
     * @notice Returns the current value of an investor's investment.
     * @dev
     * The value is calculated using the current price of the associated
     * investment product and the investor's token balance.
     *
     * @param investmentId Unique identifier of the investment product.
     * @param investor Address of the investor whose investment is valued.
     * @return value Current stablecoin-denominated value of the investor's
     *         investment.
     */
    function getInvestmentValue(uint256 investmentId, address investor) external view returns (uint256 value);

    /**
     * @notice Calculates the amount of investment tokens corresponding to a
     *         stablecoin investment.
     * @param investmentId Unique identifier of the investment product.
     * @param usdcAmount Amount of stablecoin to convert into investment tokens.
     * @return tokenAmount Number of investment tokens corresponding to the
     *         specified stablecoin amount.
     */
    function getTokenAmount(uint256 investmentId, uint256 usdcAmount) external view returns (uint256 tokenAmount);

    /**
     * @notice Calculates the stablecoin value corresponding to a given number
     *         of investment tokens.
     * @param investmentId Unique identifier of the investment product.
     * @param tokenAmount Number of investment tokens to value.
     * @return usdcAmount Stablecoin value corresponding to the specified
     *         investment token amount.
     */
    function getUSDCAmount(uint256 investmentId, uint256 tokenAmount) external view returns (uint256 usdcAmount);

    /**
     * @notice Returns the address of the stablecoin used by the investment pool.
     * @return stablecoinAddress Address of the configured stablecoin contract.
     */
    function stablecoin() external view returns (address stablecoinAddress);

    /**
     * @notice Returns the address of the investment registry used by the pool.
     * @return registryAddress Address of the configured investment registry.
     */
    function investmentRegistry() external view returns (address registryAddress);

    /**
     * @notice Returns the address of the pool administrator.
     * @return adminAddress Address authorized to perform administrative operations.
     */
    function admin() external view returns (address adminAddress);
}
