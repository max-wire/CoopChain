// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IActuarialEngine
 * @author Maxwell Wire
 * @notice Interface for actuarial and financial mathematics calculations.
 */
interface IActuarialEngine {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidPrincipal();
    error InvalidRate();
    error InvalidPeriods();

    /*//////////////////////////////////////////////////////////////
                            CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates simple interest.
     * @param principal Initial amount invested or borrowed.
     * @param annualRateBps Annual interest rate in basis points.
     * @param periods Number of compounding periods.
     * @return interestEarned Interest generated.
     * @return totalAmount Principal plus interest.
     */
    function simpleInterest(uint256 principal, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 interestEarned, uint256 totalAmount);

    /**
     * @notice Calculates compound interest.
     * @param principal Initial amount invested or borrowed.
     * @param annualRateBps Annual interest rate in basis points.
     * @param periods Number of compounding periods.
     * @return interestEarned Interest generated.
     * @return totalAmount Final accumulated amount.
     */
    function compoundInterest(uint256 principal, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 interestEarned, uint256 totalAmount);

    /**
     * @notice Calculates the future value of an investment.
     * @param principal Initial amount invested.
     * @param annualRateBps Annual interest rate in basis points.
     * @param periods Number of compounding periods.
     * @return futureValue_ Accumulated value after growth.
     */
    function futureValue(uint256 principal, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 futureValue_);

    /**
     * @notice Calculates the present value of a future amount.
     * @param futureValue_ Future amount to discount.
     * @param annualRateBps Annual discount rate in basis points.
     * @param periods Number of discounting periods.
     * @return presentValue_ Current discounted value.
     */
    function presentValue(uint256 futureValue_, uint256 annualRateBps, uint256 periods)
        external
        pure
        returns (uint256 presentValue_);

    /*//////////////////////////////////////////////////////////////
                         LOAN CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the fixed monthly payment for a loan.
     * @param principal Loan principal.
     * @param annualRateBps Annual interest rate in basis points.
     * @param months Loan duration in months.
     * @return monthlyPayment Fixed monthly installment.
     * @return totalRepayment Total amount repaid over the loan term.
     */
    function calculateMonthlyPayment(uint256 principal, uint256 annualRateBps, uint256 months)
        external
        pure
        returns (uint256 monthlyPayment, uint256 totalRepayment);
}
