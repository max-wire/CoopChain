// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IInvestmentToken} from "../interfaces/IInvestmentToken.sol";

/**
 * @title InvestmentToken
 * @author Maxwell Wire
 * @notice ERC20 representation of units in a cooperative investment product.
 *
 * @dev
 * InvestmentToken does not handle:
 * - investment purchases
 * - USDC payments
 * - investment pricing
 * - investment returns
 * - withdrawals
 * - portfolio accounting
 *
 * Those responsibilities belong to the InvestmentPool and related contracts.
 *
 * The token only represents ownership of units in a registered investment
 * product.
 */
contract InvestmentToken is ERC20, IInvestmentToken {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Investment product represented by this token.
    uint256 private immutable i_investmentId;

    /// @notice Address responsible for issuing the investment product.
    address private immutable i_issuer;

    /// @notice Maximum number of tokens that can ever exist.
    uint256 private immutable i_maxSupply;

    /// @notice Address authorized to mint and burn tokens.
    address private s_minter;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param name_ ERC20 token name.
     * @param symbol_ ERC20 token symbol.
     * @param investmentId_ ID assigned by InvestmentRegistry.
     * @param issuer_ Investment product issuer.
     * @param maxSupply_ Maximum number of investment units.
     * @param minter_ Initial address authorized to mint/burn.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 investmentId_,
        address issuer_,
        uint256 maxSupply_,
        address minter_
    ) ERC20(name_, symbol_) {
        if (investmentId_ == 0) {
            revert InvalidInvestmentId();
        }

        if (issuer_ == address(0)) {
            revert InvalidAddress();
        }

        if (maxSupply_ == 0) {
            revert InvalidMaxSupply();
        }

        if (minter_ == address(0)) {
            revert InvalidAddress();
        }

        i_investmentId = investmentId_;
        i_issuer = issuer_;
        i_maxSupply = maxSupply_;
        s_minter = minter_;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyMinter() {
        if (msg.sender != s_minter) {
            revert Unauthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                         MINTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the address authorized to mint and burn tokens.
     * @param newMinter New authorized minter.
     */
    function setMinter(address newMinter) external override onlyMinter {
        if (newMinter == address(0)) {
            revert InvalidAddress();
        }

        address previousMinter = s_minter;
        s_minter = newMinter;

        emit MinterUpdated(previousMinter, newMinter);
    }

    /*//////////////////////////////////////////////////////////////
                              MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates new investment tokens.
     * @dev Only the authorized minter can call this function.
     * @param account Account receiving the tokens.
     * @param amount Number of tokens to mint.
     */
    function mint(address account, uint256 amount) external override onlyMinter {
        if (account == address(0)) {
            revert InvalidAddress();
        }

        if (totalSupply() + amount > i_maxSupply) {
            revert ExceedsMaxSupply();
        }

        _mint(account, amount);

        emit TokensMinted(account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              BURNING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Burns investment tokens from an account.
     * @dev Only the authorized minter can call this function.
     * @param account Account whose tokens are burned.
     * @param amount Number of tokens to burn.
     */
    function burn(address account, uint256 amount) external override onlyMinter {
        if (account == address(0)) {
            revert InvalidAddress();
        }

        if (balanceOf(account) < amount) {
            revert InsufficientBalance();
        }

        _burn(account, amount);

        emit TokensBurned(account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the investment product ID represented by this token.
     */
    function investmentId() external view override returns (uint256) {
        return i_investmentId;
    }

    /**
     * @notice Returns the issuer of the investment product.
     */
    function issuer() external view override returns (address) {
        return i_issuer;
    }

    /**
     * @notice Returns the maximum token supply.
     */
    function maxSupply() external view override returns (uint256) {
        return i_maxSupply;
    }

    /**
     * @notice Returns the address authorized to mint and burn.
     */
    function minter() external view override returns (address) {
        return s_minter;
    }
}
