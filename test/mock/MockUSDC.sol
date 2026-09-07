// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @author Maxwell Wire
 * @notice Test ERC20 token used as the stablecoin for InvestmentPool tests.
 * @dev Provides an unrestricted mint function for test setup and funding.
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    /**
     * @notice Mints mock USDC to an account.
     * @param account Address receiving the tokens.
     * @param amount Amount of mock USDC to mint.
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
