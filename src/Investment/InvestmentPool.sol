// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IInvestmentPool} from "../interfaces/IInvestmentPool.sol";
import {IInvestmentRegistry} from "../interfaces/IInvestmentRegistry.sol";
import {InvestmentToken} from "../Investment/InvestmentToken.sol";

/**
 * @title InvestmentPool
 * @author Maxwell Wire
 *
 * @notice
 * Handles stablecoin investment and redemption for registered investment
 * products.
 *
 * @dev
 * InvestmentPool is responsible for capital flow between investors,
 * stablecoin liquidity, and investment tokens.
 *
 * The core architecture is:
 *
 * InvestmentRegistry
 *      │
 *      │ investment metadata
 *      ▼
 * InvestmentPool
 *      │
 *      ├── stablecoin deposits
 *      ├── investment token minting
 *      ├── investment token burning
 *      └── stablecoin redemptions
 *               │
 *               ▼
 *        InvestmentToken
 *
 * InvestmentRegistry:
 *      Defines investment products and their current prices.
 *
 * InvestmentToken:
 *      Represents ownership units of a registered investment.
 *
 * InvestmentPool:
 *      Handles stablecoin <-> investment token settlement.
 *
 * V1 intentionally does not handle:
 * - portfolio allocation
 * - external asset purchases
 * - investment returns
 * - dividends
 * - price oracles
 * - secondary markets
 * - cross-chain settlement
 *
 * @dev
 * InvestmentToken requires an authorized minter at deployment.
 * Because InvestmentPool does not exist yet when InvestmentToken is deployed,
 * the deployment sequence is:
 *
 * 1. Deploy InvestmentRegistry.
 * 2. Deploy InvestmentToken with the deployer/admin as the initial minter.
 * 3. Deploy InvestmentPool with the InvestmentRegistry and stablecoin.
 * 4. Call InvestmentToken.setMinter(InvestmentPool).
 * 5. Register the investment using the deployed InvestmentToken address.
 *
 * After step 4, InvestmentPool becomes the only address authorized to mint
 * and burn the investment token.
 *
 * This avoids a circular constructor dependency between InvestmentToken and
 * InvestmentPool.
 *
 * @dev
 * V1 redemption uses the current investment price stored in
 * InvestmentRegistry. Therefore, if the registry price changes after an
 * investment is purchased, the redemption value changes accordingly.
 *
 * V1 does not yet use an investment oracle or external valuation source.
 */
contract InvestmentPool is IInvestmentPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Stablecoin used for investment purchases and redemptions.
    IERC20 private immutable i_stablecoin;

    /// @notice Registry containing investment product metadata and prices.
    IInvestmentRegistry private immutable i_investmentRegistry;

    /// @notice Pool administrator.
    address private immutable i_admin;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the InvestmentPool.
     *
     * @dev
     * The pool administrator is set to the deployer.
     *
     * @param stablecoin_ Address of the stablecoin contract.
     * @param investmentRegistry_ Address of the InvestmentRegistry contract.
     */
    constructor(address stablecoin_, address investmentRegistry_) {
        if (stablecoin_ == address(0)) {
            revert InvalidAddress();
        }

        if (investmentRegistry_ == address(0)) {
            revert InvalidAddress();
        }

        i_stablecoin = IERC20(stablecoin_);
        i_investmentRegistry = IInvestmentRegistry(investmentRegistry_);
        i_admin = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts a function to the pool administrator.
     */
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Unauthorized();
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                           INVESTMENT FLOW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Invests stablecoin into an active investment product.
     *
     * @dev
     * The caller must approve InvestmentPool to spend the required amount
     * of stablecoin before calling this function.
     *
     * The investment price is obtained from InvestmentRegistry.
     * InvestmentPool then:
     *
     * 1. Transfers stablecoin from the investor.
     * 2. Calculates the corresponding investment token amount.
     * 3. Mints investment tokens to the investor.
     *
     * InvestmentPool must be the authorized minter of the investment token.
     *
     * @param investmentId Registered investment product ID.
     * @param usdcAmount Amount of stablecoin to invest.
     *
     * @return tokenAmount Number of investment tokens minted.
     */
    function invest(uint256 investmentId, uint256 usdcAmount)
        external
        override
        nonReentrant
        returns (uint256 tokenAmount)
    {
        if (usdcAmount == 0) {
            revert InvalidAmount();
        }

        IInvestmentRegistry.Investment memory investment = _getActiveInvestment(investmentId);

        if (investment.token == address(0)) {
            revert InvalidToken();
        }

        tokenAmount = _calculateTokenAmount(usdcAmount, investment.price);

        if (tokenAmount == 0) {
            revert InvalidAmount();
        }

        i_stablecoin.safeTransferFrom(msg.sender, address(this), usdcAmount);

        InvestmentToken(investment.token).mint(msg.sender, tokenAmount);

        emit InvestmentPurchased(msg.sender, investmentId, usdcAmount, tokenAmount);
    }

    /**
     * @notice Redeems investment tokens for stablecoin.
     *
     * @dev
     * The redemption value is calculated using the investment's current
     * price in InvestmentRegistry.
     *
     * The caller must:
     * - hold sufficient investment tokens
     * - redeem a non-zero amount
     * - use an active investment
     *
     * The pool must have sufficient stablecoin liquidity to complete
     * the redemption.
     *
     * InvestmentPool must be the authorized minter/burner of the
     * investment token.
     *
     * @param investmentId Registered investment product ID.
     * @param tokenAmount Amount of investment tokens to redeem.
     *
     * @return usdcAmount Amount of stablecoin returned to the investor.
     */
    function redeem(uint256 investmentId, uint256 tokenAmount)
        external
        override
        nonReentrant
        returns (uint256 usdcAmount)
    {
        if (tokenAmount == 0) {
            revert InvalidAmount();
        }

        IInvestmentRegistry.Investment memory investment = _getActiveInvestment(investmentId);

        if (investment.token == address(0)) {
            revert InvalidToken();
        }

        InvestmentToken investmentToken = InvestmentToken(investment.token);

        if (investmentToken.balanceOf(msg.sender) < tokenAmount) {
            revert InsufficientTokenBalance();
        }

        usdcAmount = _calculateUSDCAmount(tokenAmount, investment.price);

        if (usdcAmount == 0) {
            revert InvalidAmount();
        }

        if (i_stablecoin.balanceOf(address(this)) < usdcAmount) {
            revert InsufficientPoolBalance();
        }

        investmentToken.burn(msg.sender, tokenAmount);

        i_stablecoin.safeTransfer(msg.sender, usdcAmount);

        emit InvestmentRedeemed(msg.sender, investmentId, tokenAmount, usdcAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds stablecoin liquidity to the investment pool.
     *
     * @dev
     * Anyone may fund the pool.
     *
     * Pool liquidity may be used to satisfy investment redemptions.
     *
     * @param amount Amount of stablecoin to add to the pool.
     */
    function fund(uint256 amount) external override nonReentrant {
        if (amount == 0) {
            revert InvalidAmount();
        }

        i_stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        emit PoolFunded(msg.sender, amount);
    }

    /**
     * @notice Withdraws stablecoin from the investment pool.
     *
     * @dev
     * This is an admin-only V1 treasury operation.
     *
     * The pool must have sufficient stablecoin liquidity.
     *
     * @param recipient Address receiving the withdrawn stablecoin.
     * @param amount Amount of stablecoin to withdraw.
     */
    function withdraw(address recipient, uint256 amount) external override onlyAdmin nonReentrant {
        if (recipient == address(0)) {
            revert InvalidAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (i_stablecoin.balanceOf(address(this)) < amount) {
            revert InsufficientPoolBalance();
        }

        i_stablecoin.safeTransfer(recipient, amount);

        emit PoolWithdrawn(recipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         INVESTMENT CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the number of investment tokens corresponding
     *         to a given stablecoin investment.
     *
     * @dev
     * InvestmentToken uses 18 decimals while USDC is expected to use
     * 6 decimals.
     *
     * The calculation is:
     *
     * tokenAmount = usdcAmount * 1e18 / price
     *
     * OpenZeppelin Math.mulDiv is used to perform the multiplication
     * and division safely without an intermediate multiplication
     * overflow.
     *
     * Example:
     *
     * price = 100 USDC
     * investment = 1,000 USDC
     *
     * result = 10 InvestmentTokens.
     *
     * @param investmentId Registered investment product ID.
     * @param usdcAmount Amount of stablecoin to convert.
     *
     * @return tokenAmount Corresponding investment token amount.
     */
    function getTokenAmount(uint256 investmentId, uint256 usdcAmount)
        external
        view
        override
        returns (uint256 tokenAmount)
    {
        if (usdcAmount == 0) {
            revert InvalidAmount();
        }

        IInvestmentRegistry.Investment memory investment = _getActiveInvestment(investmentId);

        tokenAmount = _calculateTokenAmount(usdcAmount, investment.price);
    }

    /**
     * @notice Calculates the stablecoin value of a given amount of
     *         investment tokens.
     *
     * @dev
     * The calculation is:
     *
     * usdcAmount = tokenAmount * price / 1e18
     *
     * OpenZeppelin Math.mulDiv is used to avoid intermediate
     * multiplication overflow.
     *
     * @param investmentId Registered investment product ID.
     * @param tokenAmount Amount of investment tokens to convert.
     *
     * @return usdcAmount Corresponding stablecoin amount.
     */
    function getUSDCAmount(uint256 investmentId, uint256 tokenAmount)
        external
        view
        override
        returns (uint256 usdcAmount)
    {
        if (tokenAmount == 0) {
            revert InvalidAmount();
        }

        IInvestmentRegistry.Investment memory investment = _getActiveInvestment(investmentId);

        usdcAmount = _calculateUSDCAmount(tokenAmount, investment.price);
    }

    /**
     * @notice Returns the current stablecoin value of an investor's
     *         investment position.
     *
     * @dev
     * The value is determined from the investor's investment token
     * balance and the investment's current registry price.
     *
     * If the investor has no investment tokens, this function returns zero.
     *
     * @param investmentId Registered investment product ID.
     * @param investor Address of the investor.
     *
     * @return value Current stablecoin-denominated value of the position.
     */
    function getInvestmentValue(uint256 investmentId, address investor) external view override returns (uint256 value) {
        if (investor == address(0)) {
            revert InvalidAddress();
        }

        IInvestmentRegistry.Investment memory investment = _getActiveInvestment(investmentId);

        if (investment.token == address(0)) {
            revert InvalidToken();
        }

        uint256 tokenBalance = InvestmentToken(investment.token).balanceOf(investor);

        if (tokenBalance == 0) {
            return 0;
        }

        return _calculateUSDCAmount(tokenBalance, investment.price);
    }

    /*//////////////////////////////////////////////////////////////
                            CALCULATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Converts a stablecoin amount into 18-decimal investment
     *      token units.
     *
     * Uses Math.mulDiv to prevent overflow during the intermediate
     * multiplication.
     *
     * @param usdcAmount Stablecoin amount using stablecoin decimals.
     * @param price Investment price using stablecoin decimals.
     *
     * @return tokenAmount Corresponding 18-decimal token amount.
     */
    function _calculateTokenAmount(uint256 usdcAmount, uint256 price) internal pure returns (uint256 tokenAmount) {
        if (price == 0) {
            revert InvalidAmount();
        }

        return Math.mulDiv(usdcAmount, 1e18, price);
    }

    /**
     * @dev Converts 18-decimal investment token units into the
     *      stablecoin's decimal representation.
     *
     * Uses Math.mulDiv to prevent overflow during the intermediate
     * multiplication.
     *
     * @param tokenAmount Investment token amount using 18 decimals.
     * @param price Investment price using stablecoin decimals.
     *
     * @return usdcAmount Corresponding stablecoin amount.
     */
    function _calculateUSDCAmount(uint256 tokenAmount, uint256 price) internal pure returns (uint256 usdcAmount) {
        if (price == 0) {
            revert InvalidAmount();
        }

        return Math.mulDiv(tokenAmount, price, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                             VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns an investment and verifies that it exists and is active.
     *
     * @param investmentId Investment product ID to retrieve.
     *
     * @return investment Registered investment information.
     */
    function _getActiveInvestment(uint256 investmentId)
        internal
        view
        returns (IInvestmentRegistry.Investment memory investment)
    {
        try i_investmentRegistry.getInvestment(investmentId) returns (IInvestmentRegistry.Investment memory result) {
            investment = result;
        } catch {
            revert InvestmentNotFound();
        }

        if (!investment.active) {
            revert InvestmentInactive();
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the stablecoin used by the pool.
     *
     * @return stablecoinAddress Stablecoin contract address.
     */
    function stablecoin() external view override returns (address stablecoinAddress) {
        return address(i_stablecoin);
    }

    /**
     * @notice Returns the address of the InvestmentRegistry.
     *
     * @return registryAddress InvestmentRegistry contract address.
     */
    function investmentRegistry() external view override returns (address registryAddress) {
        return address(i_investmentRegistry);
    }

    /**
     * @notice Returns the address of the pool administrator.
     *
     * @return adminAddress Pool administrator address.
     */
    function admin() external view override returns (address adminAddress) {
        return i_admin;
    }
}
