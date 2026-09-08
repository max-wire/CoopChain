// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IActuarialEngine} from "./interfaces/IActuarialEngine.sol";

/**
 * @title ActuarialEngine
 * @author Maxwell Wire
 * @notice Provides actuarial and financial mathematics calculations for CoopChain.
 * @dev
 * Monetary inputs and outputs use the native denomination of the underlying
 * asset. For the current CoopChain deployment, this is 6-decimal USDC.
 *
 * Fixed-point mathematical calculations use 1e18 precision independently
 * of the underlying asset's decimals.
 */
contract ActuarialEngine is IActuarialEngine {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant PRECISION = 1e18;
    uint256 private constant BPS = 10_000;

    /*//////////////////////////////////////////////////////////////
                        PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates simple interest.
     * @return interestEarned The interest generated.
     * @return totalAmount The principal plus interest.
     */
    function simpleInterest(uint256 principal, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 interestEarned, uint256 totalAmount)
    {
        _validateInputs(principal, annualRateBps, periods);

        interestEarned = (principal * annualRateBps * periods) / BPS;

        totalAmount = principal + interestEarned;
    }

    /**
     * @notice Calculates compound interest.
     * @return interestEarned The interest generated.
     * @return totalAmount The final accumulated amount.
     */
    function compoundInterest(uint256 principal, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 interestEarned, uint256 totalAmount)
    {
        _validateInputs(principal, annualRateBps, periods);

        totalAmount = _compoundInterest(principal, annualRateBps, periods);

        interestEarned = totalAmount - principal;
    }

    /**
     * @notice Calculates future value using compound interest.
     * @return futureValue_ The accumulated value after growth.
     */
    function futureValue(uint256 principal, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 futureValue_)
    {
        _validateInputs(principal, annualRateBps, periods);

        futureValue_ = _compoundInterest(principal, annualRateBps, periods);
    }

    /**
     * @notice Calculates present value from a future value.
     * @return presentValue_ The current discounted value.
     */
    function presentValue(uint256 futureValue_, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 presentValue_)
    {
        _validateInputs(futureValue_, annualRateBps, periods);

        uint256 rate = (annualRateBps * PRECISION) / BPS;

        uint256 onePlusRate = PRECISION + rate;

        uint256 power = _pow(onePlusRate, periods);

        presentValue_ = (futureValue_ * PRECISION) / power;
    }

    /**
     * @notice Calculates the fixed monthly payment for a loan using
     *         the annuity-immediate formula.
     *
     * Formula:
     *
     * PMT = P × i × (1 + i)^n
     *       -------------------
     *          (1 + i)^n - 1
     *
     * This is mathematically equivalent to:
     *
     * PMT = P × i / (1 - (1 + i)^(-n))
     *
     * @param principal Loan principal.
     * @param annualRateBps Annual nominal interest rate in basis points.
     * @param months Number of monthly payments.
     * @return monthlyPayment Fixed monthly installment.
     * @return totalRepayment Total scheduled repayment over the loan term.
     */
    function calculateMonthlyPayment(uint256 principal, uint256 annualRateBps, uint256 months)
        external
        pure
        returns (uint256 monthlyPayment, uint256 totalRepayment)
    {
        _validateInputs(principal, annualRateBps, months);

        /*
            Special case for a one-month loan.

            For n = 1:

                PMT = P(1 + r)

            This avoids unnecessary fixed-point rounding.
        */
        if (months == 1) {
            uint256 monthlyRate = Math.mulDiv(annualRateBps, PRECISION, BPS * 12);

            monthlyPayment = Math.mulDiv(principal, PRECISION + monthlyRate, PRECISION);

            totalRepayment = monthlyPayment;

            return (monthlyPayment, totalRepayment);
        }

        /*
            Calculate monthly interest rate.
        */
        uint256 r = Math.mulDiv(annualRateBps, PRECISION, BPS * 12);

        /*
            Calculate:

                (1 + r)^n
        */
        uint256 onePlusR = PRECISION + r;

        uint256 power = _pow(onePlusR, months);

        /*
            Calculate:

                (1 + r)^-n
        */
        uint256 inversePower = Math.mulDiv(PRECISION, PRECISION, power);

        /*
            Calculate:

                1 - (1 + r)^-n
        */
        uint256 discountFactor = PRECISION - inversePower;

        /*
            Calculate annuity factor:

                [1 - (1+r)^-n] / r
        */
        uint256 annuityFactor = Math.mulDiv(discountFactor, PRECISION, r);

        /*
            Calculate monthly payment:

                PMT = Principal / Annuity Factor
        */
        monthlyPayment = Math.mulDiv(principal, PRECISION, annuityFactor);

        /*
            Total repayment over the loan term.
        */
        totalRepayment = monthlyPayment * months;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _validateInputs(uint256 principal, uint256 annualRateBps, uint256 periods) internal pure {
        if (principal == 0) {
            revert InvalidPrincipal();
        }

        if (annualRateBps == 0) {
            revert InvalidRate();
        }

        if (periods == 0) {
            revert InvalidPeriods();
        }
    }

    /**
     * @notice Exponentiation by squaring.
     *
     * Calculates:
     *
     * base ^ exponent
     *
     * Runs in O(log n) instead of O(n).
     */
    function _pow(uint256 base, uint256 exponent) internal pure returns (uint256 result) {
        result = PRECISION;

        while (exponent > 0) {
            if (exponent & 1 == 1) {
                result = Math.mulDiv(result, base, PRECISION);
            }

            base = Math.mulDiv(base, base, PRECISION);

            exponent >>= 1;
        }
    }

    function _compoundInterest(uint256 principal, uint256 annualRateBps, uint256 periods)
        internal
        pure
        returns (uint256 totalAmount)
    {
        uint256 rate = (annualRateBps * PRECISION) / BPS;

        uint256 onePlusRate = PRECISION + rate;

        uint256 power = _pow(onePlusRate, periods);

        totalAmount = (principal * power) / PRECISION;
    }
}
