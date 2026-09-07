// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MathHelper
 * @author Maxwell Wire
 * @notice Mathematical helper functions used by InvestmentPool tests.
 * @dev Mirrors the conversion formulas used by InvestmentPool.
 */
library MathHelper {
    /**
     * @notice Converts a stablecoin amount into investment token units.
     * @param usdcValue Stablecoin amount.
     * @param price Current investment price per token.
     * @return tokenValue Equivalent investment token amount.
     */
    function tokenAmount(uint256 usdcValue, uint256 price) internal pure returns (uint256 tokenValue) {
        return Math.mulDiv(usdcValue, 1e18, price);
    }

    /**
     * @notice Converts investment token units into stablecoin value.
     * @param tokenValue Investment token amount.
     * @param price Current investment price per token.
     * @return usdcValue Equivalent stablecoin amount.
     */
    function usdcAmount(uint256 tokenValue, uint256 price) internal pure returns (uint256 usdcValue) {
        return Math.mulDiv(tokenValue, price, 1e18);
    }
}
