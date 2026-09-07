// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IInvestmentRegistry} from "../interfaces/IInvestmentRegistry.sol";

/**
 * @title InvestmentRegistry
 * @author Maxwell Wire
 * @notice Registry for cooperative investment products.
 *
 * @dev
 * The registry is responsible only for investment-product metadata and
 * lifecycle management.
 *
 * It does not:
 * - custody investment funds;
 * - transfer investment tokens;
 * - execute purchases;
 * - distribute investment returns.
 *
 * Those responsibilities belong to the investment token and pool layers.
 */
contract InvestmentRegistry is IInvestmentRegistry {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address authorized to manage investment products.
    address private immutable i_admin;

    /// @notice Next investment identifier.
    uint256 private s_nextInvestmentId;

    /// @notice Number of registered investments.
    uint256 private s_investmentCount;

    /// @notice Investment records indexed by their unique identifier.
    mapping(uint256 => Investment) private s_investments;

    /// @notice List of all investment identifiers.
    uint256[] private s_investmentIds;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the investment registry.
     * @dev The deployer becomes the registry administrator.
     */
    constructor() {
        i_admin = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts an operation to the registry administrator.
     */
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Unauthorized();
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function createInvestment(
        string calldata name,
        string calldata symbol,
        AssetType assetType,
        address token,
        address issuer,
        uint256 price,
        uint256 totalSupply
    ) external onlyAdmin returns (uint256 investmentId) {
        _validateInvestment(name, symbol, token, issuer, price, totalSupply);

        investmentId = ++s_nextInvestmentId;

        s_investments[investmentId] = Investment({
            id: investmentId,
            name: name,
            symbol: symbol,
            assetType: assetType,
            token: token,
            issuer: issuer,
            price: price,
            totalSupply: totalSupply,
            active: true
        });

        s_investmentIds.push(investmentId);
        ++s_investmentCount;

        emit InvestmentCreated(investmentId, name, symbol, assetType, issuer, token, price, totalSupply);
    }

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function updateInvestment(uint256 investmentId, uint256 price, uint256 totalSupply) external onlyAdmin {
        Investment storage investment = s_investments[investmentId];

        _validateInvestmentExists(investment);

        if (!investment.active) {
            revert InvestmentInactive();
        }

        if (price == 0) {
            revert InvalidPrice();
        }

        if (totalSupply == 0) {
            revert InvalidSupply();
        }

        investment.price = price;
        investment.totalSupply = totalSupply;

        emit InvestmentUpdated(investmentId, price, totalSupply, investment.active);
    }

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function deactivateInvestment(uint256 investmentId) external onlyAdmin {
        Investment storage investment = s_investments[investmentId];

        _validateInvestmentExists(investment);

        if (!investment.active) {
            revert InvestmentAlreadyInactive();
        }

        investment.active = false;

        emit InvestmentDeactivated(investmentId);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function getInvestment(uint256 investmentId) external view returns (Investment memory investment) {
        investment = s_investments[investmentId];

        if (investment.id == 0) {
            revert InvestmentNotFound();
        }
    }

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function getInvestmentCount() external view returns (uint256 count) {
        return s_investmentCount;
    }

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function getInvestmentIds() external view returns (uint256[] memory investmentIds) {
        return s_investmentIds;
    }

    /**
     * @inheritdoc IInvestmentRegistry
     */
    function isInvestmentActive(uint256 investmentId) external view returns (bool active) {
        Investment memory investment = s_investments[investmentId];

        if (investment.id == 0) {
            return false;
        }

        return investment.active;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the registry administrator.
     * @return admin Address authorized to manage investments.
     */
    function getAdmin() external view returns (address admin) {
        return i_admin;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates investment creation parameters.
     */
    function _validateInvestment(
        string calldata name,
        string calldata symbol,
        address token,
        address issuer,
        uint256 price,
        uint256 totalSupply
    ) internal pure {
        if (bytes(name).length == 0) {
            revert InvalidName();
        }

        if (bytes(symbol).length == 0) {
            revert InvalidSymbol();
        }

        if (token == address(0)) {
            revert InvalidAddress();
        }

        if (issuer == address(0)) {
            revert InvalidAddress();
        }

        if (price == 0) {
            revert InvalidPrice();
        }

        if (totalSupply == 0) {
            revert InvalidSupply();
        }
    }

    /**
     * @notice Ensures an investment exists.
     */
    function _validateInvestmentExists(Investment storage investment) internal view {
        if (investment.id == 0) {
            revert InvestmentNotFound();
        }
    }
}
