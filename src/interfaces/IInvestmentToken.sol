// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IInvestmentToken
 * @author Maxwell Wire
 * @notice Interface for ERC20 tokens representing units of a cooperative
 *         investment product.
 * @dev Defines the core functionality for investment tokens, including
 *      controlled minting and burning, maximum supply enforcement, and
 *      minter management.
 */
interface IInvestmentToken {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an invalid or zero address is provided.
    error InvalidAddress();

    /// @notice Thrown when an invalid investment ID is provided.
    error InvalidInvestmentId();

    /// @notice Thrown when an invalid maximum supply is provided.
    error InvalidMaxSupply();

    /// @notice Thrown when the caller is not authorized to perform the operation.
    error Unauthorized();

    /// @notice Thrown when minting would cause the token supply to exceed the maximum supply.
    error ExceedsMaxSupply();

    /// @notice Thrown when an account does not have sufficient token balance for a burn.
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the authorized minter is changed.
     * @param previousMinter Address of the previous authorized minter.
     * @param newMinter Address of the new authorized minter.
     */
    event MinterUpdated(address indexed previousMinter, address indexed newMinter);

    /**
     * @notice Emitted when investment tokens are minted.
     * @param account Address receiving the newly minted tokens.
     * @param amount Number of tokens minted.
     */
    event TokensMinted(address indexed account, uint256 amount);

    /**
     * @notice Emitted when investment tokens are burned.
     * @param account Address whose tokens are burned.
     * @param amount Number of tokens burned.
     */
    event TokensBurned(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the unique investment product ID represented by this token.
     * @return id Unique identifier of the associated investment product.
     */
    function investmentId() external view returns (uint256 id);

    /**
     * @notice Returns the address of the investment product issuer.
     * @return issuerAddress Address responsible for issuing the investment product.
     */
    function issuer() external view returns (address issuerAddress);

    /**
     * @notice Returns the maximum number of tokens that may ever exist.
     * @return supply Maximum token supply.
     */
    function maxSupply() external view returns (uint256 supply);

    /**
     * @notice Returns the address authorized to mint and burn investment tokens.
     * @return minterAddress Address of the current authorized minter.
     */
    function minter() external view returns (address minterAddress);

    /**
     * @notice Updates the address authorized to mint and burn tokens.
     * @dev The caller must have the required authorization to change the minter.
     * @param newMinter Address to authorize as the new minter.
     */
    function setMinter(address newMinter) external;

    /**
     * @notice Mints investment tokens to an account.
     * @dev The caller must be authorized to mint tokens. The resulting total
     *      supply must not exceed the configured maximum supply.
     * @param account Address receiving the newly minted tokens.
     * @param amount Number of tokens to mint.
     */
    function mint(address account, uint256 amount) external;

    /**
     * @notice Burns investment tokens from an account.
     * @dev The caller must be authorized to burn tokens and the account must
     *      have sufficient balance.
     * @param account Address whose tokens will be burned.
     * @param amount Number of tokens to burn.
     */
    function burn(address account, uint256 amount) external;
}
