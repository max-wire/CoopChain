// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICoopVault} from "./interfaces/ICoopVault.sol";
import {ISavings} from "./interfaces/ISavings.sol";
import {ICreditScore} from "./interfaces/ICreditScore.sol";
import {IActuarialEngine} from "./interfaces/IActuarialEngine.sol";
import {ILoanEngine} from "./interfaces/ILoanEngine.sol";

contract LoanEngine is ILoanEngine {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant VERY_LOW_RATE_BPS = 500;
    uint256 private constant LOW_RATE_BPS = 700;
    uint256 private constant MEDIUM_RATE_BPS = 1_000;
    uint256 private constant HIGH_RATE_BPS = 1_500;

    // A member's borrowing capacity is linked to their savings.
    // Maximum loan = 3x member savings.
    uint256 private constant MAX_LOAN_MULTIPLE = 3;

    // One repayment period is 30 days.
    uint256 private constant PAYMENT_INTERVAL = 30 days;

    // Borrower receives a 7-day grace period after the due date.
    uint256 private constant DEFAULT_GRACE_PERIOD = 7 days;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ICoopVault private immutable i_coopVault;
    ISavings private immutable i_savings;
    ICreditScore private immutable i_creditScore;
    IActuarialEngine private immutable i_actuarialEngine;

    IERC20 public immutable i_stableCoin;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_nextLoanId;

    mapping(uint256 => Loan) private s_loans;

    mapping(address => uint256[]) private s_memberLoans;

    uint256 private s_totalLoansIssued;

    uint256 private s_totalOutstandingDebt;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address coopVault,
        address savings,
        address creditScore,
        address actuarialEngineAddress,
        address _stableCoin
    ) {
        if (coopVault == address(0)) revert InvalidAddress();
        if (savings == address(0)) revert InvalidAddress();
        if (creditScore == address(0)) revert InvalidAddress();
        if (actuarialEngineAddress == address(0)) revert InvalidAddress();
        if (_stableCoin == address(0)) revert InvalidAddress();

        i_coopVault = ICoopVault(coopVault);
        i_savings = ISavings(savings);
        i_creditScore = ICreditScore(creditScore);
        i_actuarialEngine = IActuarialEngine(actuarialEngineAddress);
        i_stableCoin = IERC20(_stableCoin);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows an active cooperative member to request and receive
     *         a loan immediately.
     *
     * @dev Version 1 lending flow remains unchanged:
     *
     *      Member
     *        |
     *        v
     *      Validate membership
     *        |
     *        v
     *      Validate savings and loan limits
     *        |
     *        v
     *      Assess credit risk
     *        |
     *        v
     *      Calculate loan terms
     *        |
     *        v
     *      Create loan
     *        |
     *        v
     *      Update accounting
     *        |
     *        v
     *      Transfer stablecoin
     *
     *      The main addition is a repayment schedule:
     *      - Monthly payment
     *      - Next due date
     *      - Default grace period
     *
     * @param principal Amount of stablecoin requested.
     * @param duration Loan duration in months.
     */
    function applyForLoan(uint256 principal, uint256 duration) external {
        _validateMember(msg.sender);

        _validateLoanAmount(msg.sender, principal);

        if (duration == 0) {
            revert InvalidDuration();
        }

        uint256 interestRateBps = _determineInterestRate(msg.sender);

        LoanTerms memory terms = _calculateLoanTerms(principal, interestRateBps, duration);

        uint256 loanId = _createLoan(msg.sender, terms);

        _recordLoanIssued(terms.totalRepayment);

        i_stableCoin.safeTransfer(msg.sender, principal);

        emit LoanCreated(
            loanId,
            msg.sender,
            principal,
            interestRateBps,
            duration,
            terms.monthlyPayment,
            terms.totalRepayment,
            s_loans[loanId].nextDueDate
        );
    }

    /**
     * @notice Allows a borrower to make a scheduled repayment.
     *
     * @dev Repayment rules:
     *
     *      - Regular installments must equal monthlyPayment.
     *      - The final payment may be less than monthlyPayment if
     *        rounding created a smaller remaining balance.
     *      - After a successful installment, nextDueDate advances
     *        by 30 days.
     *
     *      This keeps the existing repayment workflow while adding
     *      a predictable repayment schedule.
     *
     * @param loanId Identifier of the loan being repaid.
     * @param amount Amount of stablecoin being repaid.
     */
    function repayLoan(uint256 loanId, uint256 amount) external {
        Loan storage loan = s_loans[loanId];

        if (loan.loanId == 0) {
            revert LoanNotFound();
        }

        if (loan.borrower != msg.sender) {
            revert NotLoanBorrower();
        }

        if (loan.status != LoanStatus.Active) {
            revert LoanNotActive();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 remainingBalance = loan.totalRepayment - loan.amountRepaid;

        if (amount > remainingBalance) {
            revert InvalidAmount();
        }

        /*
         * Regular payments must match the scheduled monthly payment.
         *
         * The only exception is the final payment, where the remaining
         * balance may be smaller than the scheduled installment.
         */
        if (amount != loan.monthlyPayment && amount != remainingBalance) {
            revert InvalidAmount();
        }

        i_stableCoin.safeTransferFrom(msg.sender, address(this), amount);

        loan.amountRepaid += amount;

        _recordRepayment(amount);

        /*
         * Fully repaid loans are immediately marked as Repaid.
         */
        if (loan.amountRepaid == loan.totalRepayment) {
            loan.status = LoanStatus.Repaid;
        } else {
            /*
             * Advance the next payment date only after a successful
             * scheduled payment.
             */
            loan.nextDueDate += PAYMENT_INTERVAL;
        }

        emit LoanRepaid(loanId, msg.sender, amount);
    }

    /**
     * @notice Marks an overdue loan as defaulted.
     *
     * @dev Default rules:
     *
     *      A loan can be marked defaulted only when:
     *
     *      block.timestamp >
     *      nextDueDate + DEFAULT_GRACE_PERIOD
     *
     *      and the loan still has an outstanding balance.
     *
     *      Default marking remains permissionless. Anyone can call
     *      this function once the objective default condition has
     *      been reached.
     *
     * @param loanId Identifier of the loan to mark as defaulted.
     */
    function markDefaulted(uint256 loanId) external {
        Loan storage loan = s_loans[loanId];

        if (loan.loanId == 0) {
            revert LoanNotFound();
        }

        if (loan.status != LoanStatus.Active) {
            revert LoanNotActive();
        }

        /*
         * The borrower is still within the grace period.
         */
        if (block.timestamp <= loan.nextDueDate + DEFAULT_GRACE_PERIOD) {
            revert PaymentNotDue();
        }

        /*
         * Nothing remains to be paid.
         */
        if (loan.amountRepaid >= loan.totalRepayment) {
            revert LoanAlreadyRepaid();
        }

        loan.status = LoanStatus.Defaulted;

        emit LoanDefaulted(loanId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that a borrower is an active coop member.
     */
    function _validateMember(address member) internal view returns (ICoopVault.Member memory coopMember) {
        coopMember = i_coopVault.getMember(member);

        if (!coopMember.active) {
            revert MemberInactive();
        }
    }

    /**
     * @notice Validates whether a requested loan amount is eligible.
     */
    function _validateLoanAmount(address borrower, uint256 principal) internal view {
        if (principal == 0) {
            revert InvalidLoanAmount();
        }

        ISavings.SavingsAccount memory account = i_savings.getSavingsAccount(borrower);

        uint256 savingsBalance = account.balance;

        if (savingsBalance == 0) {
            revert NoSavings();
        }

        /*
         * Maximum loan = 3x member savings.
         */
        if (principal > savingsBalance * MAX_LOAN_MULTIPLE) {
            revert LoanAmountTooHigh();
        }

        /*
         * Ensure protocol has sufficient liquidity.
         */
        if (i_stableCoin.balanceOf(address(this)) < principal) {
            revert InsufficientLiquidity();
        }

        /*
         * Version 1 allows only one active loan per member.
         */
        if (_hasActiveLoan(borrower)) {
            revert ActiveLoanExists();
        }
    }

    /**
     * @notice Determines the borrower's interest rate from their
     *         credit risk tier.
     */
    function _determineInterestRate(address borrower) internal view returns (uint256) {
        ICreditScore.RiskTier riskTier = i_creditScore.getRiskTier(borrower);

        if (riskTier == ICreditScore.RiskTier.VeryLow) {
            return VERY_LOW_RATE_BPS;
        }

        if (riskTier == ICreditScore.RiskTier.Low) {
            return LOW_RATE_BPS;
        }

        if (riskTier == ICreditScore.RiskTier.Medium) {
            return MEDIUM_RATE_BPS;
        }

        if (riskTier == ICreditScore.RiskTier.High) {
            return HIGH_RATE_BPS;
        }

        revert RiskTooHigh();
    }

    /**
     * @notice Calculates the monthly repayment terms using the
     *         actuarial engine.
     */
    function _calculateLoanTerms(uint256 principal, uint256 interestRateBps, uint256 duration)
        internal
        view
        returns (LoanTerms memory terms)
    {
        (uint256 monthlyPayment, uint256 totalRepayment) =
            i_actuarialEngine.calculateMonthlyPayment(principal, interestRateBps, duration);

        terms = LoanTerms({
            principal: principal,
            interestRateBps: interestRateBps,
            duration: duration,
            monthlyPayment: monthlyPayment,
            totalRepayment: totalRepayment
        });
    }

    /**
     * @notice Creates and stores a new loan.
     */
    function _createLoan(address borrower, LoanTerms memory terms) internal returns (uint256 loanId) {
        loanId = ++s_nextLoanId;

        uint256 startDate = block.timestamp;

        s_loans[loanId] = Loan({
            loanId: loanId,
            borrower: borrower,
            principal: terms.principal,
            interestRateBps: terms.interestRateBps,
            duration: terms.duration,
            monthlyPayment: terms.monthlyPayment,
            totalRepayment: terms.totalRepayment,
            amountRepaid: 0,
            startDate: startDate,
            nextDueDate: startDate + PAYMENT_INTERVAL,
            status: LoanStatus.Active
        });

        s_memberLoans[borrower].push(loanId);
    }

    /**
     * @notice Records accounting changes when a new loan is issued.
     */
    function _recordLoanIssued(uint256 totalRepayment) internal {
        ++s_totalLoansIssued;

        s_totalOutstandingDebt += totalRepayment;
    }

    /**
     * @notice Records accounting changes when a borrower makes
     *         a repayment.
     */
    function _recordRepayment(uint256 amount) internal {
        s_totalOutstandingDebt -= amount;
    }

    /**
     * @notice Returns whether a borrower has an active loan.
     */
    function _hasActiveLoan(address borrower) internal view returns (bool) {
        uint256[] storage loanIds = s_memberLoans[borrower];

        for (uint256 i = 0; i < loanIds.length; ++i) {
            if (s_loans[loanIds[i]].status == LoanStatus.Active) {
                return true;
            }
        }

        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns complete details of a loan.
     */
    function getLoan(uint256 loanId) external view returns (Loan memory loan) {
        if (s_loans[loanId].loanId == 0) {
            revert LoanNotFound();
        }

        return s_loans[loanId];
    }

    /**
     * @notice Returns all loans belonging to a member.
     */
    function getLoansByMember(address member) external view returns (Loan[] memory loans) {
        uint256[] memory loanIds = s_memberLoans[member];

        loans = new Loan[](loanIds.length);

        for (uint256 i = 0; i < loanIds.length; ++i) {
            loans[i] = s_loans[loanIds[i]];
        }
    }

    /**
     * @notice Returns total outstanding protocol debt.
     *
     * @dev Includes outstanding obligations from active and defaulted
     *      loans. Repaid loans are removed from outstanding debt
     *      through repayments.
     */
    function getOutstandingDebt() external view returns (uint256 outstandingDebt) {
        return s_totalOutstandingDebt;
    }

    /**
     * @notice Returns the total number of loans issued.
     */
    function getTotalLoansIssued() external view returns (uint256 totalLoans) {
        return s_totalLoansIssued;
    }

    /**
     * @notice Calculates the remaining balance of a loan.
     */
    function getRemainingBalance(uint256 loanId) external view returns (uint256 remainingBalance) {
        Loan memory loan = s_loans[loanId];

        if (loan.loanId == 0) {
            revert LoanNotFound();
        }

        return loan.totalRepayment - loan.amountRepaid;
    }

    /**
     * @notice Returns the complete repayment schedule for a loan.
     *
     * @dev The schedule is derived from the stored loan terms rather
     *      than being stored as individual records, reducing storage
     *      costs.
     *
     * @param loanId Identifier of the loan.
     * @return dueDates Array of scheduled payment dates.
     * @return payments Array of scheduled payment amounts.
     */
    function getRepaymentSchedule(uint256 loanId)
        external
        view
        returns (uint256[] memory dueDates, uint256[] memory payments)
    {
        Loan memory loan = s_loans[loanId];

        if (loan.loanId == 0) {
            revert LoanNotFound();
        }

        dueDates = new uint256[](loan.duration);
        payments = new uint256[](loan.duration);

        for (uint256 i = 0; i < loan.duration; ++i) {
            dueDates[i] = loan.startDate + ((i + 1) * PAYMENT_INTERVAL);

            /*
             * The final payment may be smaller because of rounding.
             */
            if (i == loan.duration - 1) {
                payments[i] = loan.totalRepayment - (loan.monthlyPayment * (loan.duration - 1));
            } else {
                payments[i] = loan.monthlyPayment;
            }
        }
    }
}
