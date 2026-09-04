// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ILoanEngine
 * @author Maxwell Wire
 * @notice Interface for the CoopChain lending engine.
 * @dev Defines the errors, loan data structures, events, and external
 *      functions used to manage the complete loan lifecycle.
 */
interface ILoanEngine {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a provided address is the zero address.
    error InvalidAddress();

    /// @notice Thrown when the borrower is not an active CoopChain member.
    error MemberInactive();

    /// @notice Thrown when the requested loan amount is invalid or zero.
    error InvalidLoanAmount();

    /// @notice Thrown when the borrower has no savings balance.
    error NoSavings();

    /// @notice Thrown when the requested loan exceeds the borrower's permitted limit.
    error LoanAmountTooHigh();

    /// @notice Thrown when the lending engine does not have enough liquidity
    ///         to issue or service the requested loan.
    error InsufficientLiquidity();

    /// @notice Thrown when the borrower already has an active loan.
    error ActiveLoanExists();

    /// @notice Thrown when the borrower's credit risk is above the permitted threshold.
    error RiskTooHigh();

    /// @notice Thrown when a requested loan does not exist.
    error LoanNotFound();

    /// @notice Thrown when a repayment amount is invalid.
    error InvalidAmount();

    /// @notice Thrown when the caller is not the borrower associated with the loan.
    error NotLoanBorrower();

    /// @notice Thrown when an operation requires an active loan but the loan is not active.
    error LoanNotActive();

    /// @notice Thrown when an operation requires a pending loan but the loan is not pending.
    error LoanNotPending();

    /// @notice Thrown when an attempt is made to repay a loan that has already been fully repaid.
    error LoanAlreadyRepaid();

    /// @notice Thrown when a repayment is attempted before its scheduled due date.
    error PaymentNotDue();

    /// @notice Thrown when a scheduled repayment has passed its due date.
    error PaymentOverdue();

    /// @notice Thrown when the provided loan duration is invalid.
    error InvalidDuration();

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents the current state of a loan.
     * @dev Loans progress through the lifecycle:
     *      Pending -> Active -> Repaid or Defaulted.
     *      Pending loans may also be Cancelled.
     */
    enum LoanStatus {
        /// @notice Loan application has been created but is not yet active.
        Pending,

        /// @notice Loan has been approved/disbursed and is currently active.
        Active,

        /// @notice Loan has been fully repaid.
        Repaid,

        /// @notice Loan has been classified as defaulted.
        Defaulted,

        /// @notice Loan application has been cancelled.
        Cancelled
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents the complete state of an individual loan.
     * @dev Contains the original loan terms, repayment progress, timestamps,
     *      and current lifecycle status.
     */
    struct Loan {
        /// @notice Unique identifier assigned to the loan.
        uint256 loanId;

        /// @notice Wallet address of the borrower.
        address borrower;

        /// @notice Original amount of principal borrowed.
        uint256 principal;

        /// @notice Annual interest rate expressed in basis points.
        /// @dev 100 basis points = 1%.
        uint256 interestRateBps;

        /// @notice Loan duration expressed in the protocol's configured time unit.
        uint256 duration;

        /// @notice Amount scheduled to be paid for each repayment period.
        uint256 monthlyPayment;

        /// @notice Total amount expected to be repaid over the loan duration.
        uint256 totalRepayment;

        /// @notice Total amount already repaid by the borrower.
        uint256 amountRepaid;

        /// @notice Timestamp at which the loan became active.
        uint256 startDate;

        /// @notice Timestamp of the borrower's next scheduled repayment.
        uint256 nextDueDate;

        /// @notice Current lifecycle status of the loan.
        LoanStatus status;
    }

    /**
     * @notice Contains the financial terms calculated for a loan.
     * @dev Used to represent the principal, interest, duration, and repayment
     *      amounts independently from the full loan state.
     */
    struct LoanTerms {
        /// @notice Principal amount of the loan.
        uint256 principal;

        /// @notice Annual interest rate expressed in basis points.
        /// @dev 100 basis points = 1%.
        uint256 interestRateBps;

        /// @notice Loan duration expressed in the protocol's configured time unit.
        uint256 duration;

        /// @notice Amount scheduled for each monthly repayment.
        uint256 monthlyPayment;

        /// @notice Total amount expected to be repaid over the loan duration.
        uint256 totalRepayment;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new loan is created.
     * @param loanId Unique identifier of the newly created loan.
     * @param borrower Address of the borrower.
     * @param principal Original principal amount of the loan.
     * @param interestRateBps Interest rate expressed in basis points.
     * @param duration Loan duration.
     * @param monthlyPayment Scheduled monthly repayment amount.
     * @param totalRepayment Total amount expected to be repaid.
     * @param nextDueDate Timestamp of the first scheduled repayment.
     */
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principal,
        uint256 interestRateBps,
        uint256 duration,
        uint256 monthlyPayment,
        uint256 totalRepayment,
        uint256 nextDueDate
    );

    /**
     * @notice Emitted when a borrower makes a loan repayment.
     * @param loanId Unique identifier of the repaid loan.
     * @param borrower Address of the borrower making the repayment.
     * @param amount Amount paid toward the loan.
     */
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);

    /**
     * @notice Emitted when a pending loan is cancelled.
     * @param loanId Unique identifier of the cancelled loan.
     */
    event LoanCancelled(uint256 indexed loanId);

    /**
     * @notice Emitted when an active loan is classified as defaulted.
     * @param loanId Unique identifier of the defaulted loan.
     */
    event LoanDefaulted(uint256 indexed loanId);

    /**
     * @notice Emitted when a loan repayment becomes due.
     * @param loanId Unique identifier of the loan.
     * @param dueDate Timestamp when the payment becomes due.
     * @param amount Amount scheduled for repayment.
     */
    event LoanPaymentDue(uint256 indexed loanId, uint256 dueDate, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new loan application for the caller.
     * @dev The implementing contract should validate membership status,
     *      savings, risk, loan limits, liquidity, and duration before
     *      creating the loan.
     * @param principal Amount of funds requested by the borrower.
     * @param duration Requested loan duration.
     */
    function applyForLoan(uint256 principal, uint256 duration) external;

    /**
     * @notice Repays an active loan.
     * @dev The implementing contract should update the outstanding debt,
     *      repayment progress, and loan status as appropriate.
     * @param loanId Unique identifier of the loan to repay.
     * @param amount Amount of tokens to apply toward the loan.
     */
    function repayLoan(uint256 loanId, uint256 amount) external;

    /**
     * @notice Marks a loan as defaulted.
     * @dev The implementing contract should ensure that the loan meets
     *      the protocol's configured default conditions before changing
     *      its status.
     * @param loanId Unique identifier of the loan to mark as defaulted.
     */
    function markDefaulted(uint256 loanId) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the complete information for a specific loan.
     * @param loanId Unique identifier of the loan.
     * @return loan Complete loan information.
     */
    function getLoan(uint256 loanId) external view returns (Loan memory loan);

    /**
     * @notice Returns all loans associated with a specific member.
     * @param member Address of the member whose loans should be returned.
     * @return loans Array containing the member's loans.
     */
    function getLoansByMember(address member) external view returns (Loan[] memory loans);

    /**
     * @notice Returns the total outstanding debt across the lending engine.
     * @return outstandingDebt Total principal and/or repayment debt currently outstanding,
     *         according to the implementation's accounting model.
     */
    function getOutstandingDebt() external view returns (uint256 outstandingDebt);

    /**
     * @notice Returns the total number of loans issued by the lending engine.
     * @return totalLoans Total number of loans created.
     */
    function getTotalLoansIssued() external view returns (uint256 totalLoans);

    /**
     * @notice Returns the remaining balance owed on a specific loan.
     * @param loanId Unique identifier of the loan.
     * @return remainingBalance Amount still outstanding on the loan.
     */
    function getRemainingBalance(uint256 loanId) external view returns (uint256 remainingBalance);

    /**
     * @notice Returns the repayment schedule for a specific loan.
     * @dev The returned arrays should correspond by index, with each due date
     *      matching its scheduled payment amount.
     * @param loanId Unique identifier of the loan.
     * @return dueDates Array of scheduled repayment timestamps.
     * @return payments Array of scheduled repayment amounts.
     */
    function getRepaymentSchedule(uint256 loanId)
        external
        view
        returns (uint256[] memory dueDates, uint256[] memory payments);
}
