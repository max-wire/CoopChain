// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IInvestmentRegistry
 * @author Maxwell Wire
 * @notice Interface for registering, updating, deactivating, and querying cooperative investment products.
 * @dev Supports multiple investment asset types, including equity, bonds, funds,
 *      real estate, and receivables.
 */
interface IInvestmentRegistry {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a provided address is the zero address.
    error InvalidAddress();

    /// @notice Thrown when an investment name is invalid or empty.
    error InvalidName();

    /// @notice Thrown when an investment symbol is invalid or empty.
    error InvalidSymbol();

    /// @notice Thrown when an investment price is invalid.
    error InvalidPrice();

    /// @notice Thrown when an investment total supply is invalid.
    error InvalidSupply();

    /// @notice Thrown when the specified investment does not exist.
    error InvestmentNotFound();

    /// @notice Thrown when an operation requires an active investment.
    error InvestmentInactive();

    /// @notice Thrown when attempting to deactivate an investment that is already inactive.
    error InvestmentAlreadyInactive();

    /// @notice Thrown when the caller is not authorized to perform the requested operation.
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Supported types of cooperative investment products.
    enum AssetType {
        EQUITY,
        BOND,
        FUND,
        REAL_ESTATE,
        RECEIVABLE
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents a registered cooperative investment product.
     * @param id Unique identifier assigned to the investment.
     * @param name Human-readable name of the investment product.
     * @param symbol Short symbol representing the investment product.
     * @param assetType Type of underlying investment asset.
     * @param token Address of the token representing the investment.
     * @param issuer Address responsible for issuing the investment.
     * @param price Current price per investment unit.
     * @param totalSupply Total number of investment units available.
     * @param active Whether the investment is currently active.
     */
    struct Investment {
        uint256 id;
        string name;
        string symbol;
        AssetType assetType;
        address token;
        address issuer;
        uint256 price;
        uint256 totalSupply;
        bool active;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new investment product is registered.
    /// @param investmentId Unique identifier assigned to the investment.
    /// @param name Name of the investment product.
    /// @param symbol Symbol of the investment product.
    /// @param assetType Type of the investment asset.
    /// @param issuer Address that issued the investment.
    /// @param token Address of the token representing the investment.
    /// @param price Initial price per investment unit.
    /// @param totalSupply Total number of investment units available.
    event InvestmentCreated(
        uint256 indexed investmentId,
        string name,
        string symbol,
        AssetType indexed assetType,
        address indexed issuer,
        address token,
        uint256 price,
        uint256 totalSupply
    );

    /// @notice Emitted when an existing investment's price or supply is updated.
    /// @param investmentId Unique identifier of the investment.
    /// @param price Updated price per investment unit.
    /// @param totalSupply Updated total supply of investment units.
    /// @param active Current active status of the investment.
    event InvestmentUpdated(uint256 indexed investmentId, uint256 price, uint256 totalSupply, bool active);

    /// @notice Emitted when an investment product is permanently deactivated.
    /// @param investmentId Unique identifier of the deactivated investment.
    event InvestmentDeactivated(uint256 indexed investmentId);

    /*//////////////////////////////////////////////////////////////
                        INVESTMENT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Registers a new cooperative investment product.
     * @param name Name of the investment product.
     * @param symbol Symbol of the investment product.
     * @param assetType Type of the investment asset.
     * @param token Address of the token representing the investment.
     * @param issuer Address responsible for issuing the investment.
     * @param price Initial price per investment unit.
     * @param totalSupply Total number of investment units available.
     * @return investmentId Unique identifier assigned to the newly created investment.
     */
    function createInvestment(
        string calldata name,
        string calldata symbol,
        AssetType assetType,
        address token,
        address issuer,
        uint256 price,
        uint256 totalSupply
    ) external returns (uint256 investmentId);

    /**
     * @notice Updates the price and total supply of an existing investment.
     * @param investmentId Unique identifier of the investment to update.
     * @param price New price per investment unit.
     * @param totalSupply New total supply of investment units.
     */
    function updateInvestment(uint256 investmentId, uint256 price, uint256 totalSupply) external;

    /**
     * @notice Deactivates an investment product.
     * @param investmentId Unique identifier of the investment to deactivate.
     */
    function deactivateInvestment(uint256 investmentId) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the complete details of a registered investment.
     * @param investmentId Unique identifier of the investment.
     * @return investment Investment details associated with the specified ID.
     */
    function getInvestment(uint256 investmentId) external view returns (Investment memory investment);

    /**
     * @notice Returns the total number of investments registered.
     * @return count Number of registered investment products.
     */
    function getInvestmentCount() external view returns (uint256 count);

    /**
     * @notice Returns the IDs of all registered investments.
     * @return investmentIds Array containing the IDs of registered investments.
     */
    function getInvestmentIds() external view returns (uint256[] memory investmentIds);

    /**
     * @notice Checks whether a specific investment is currently active.
     * @param investmentId Unique identifier of the investment to check.
     * @return active True if the investment exists and is active, otherwise false.
     */
    function isInvestmentActive(uint256 investmentId) external view returns (bool active);
}
