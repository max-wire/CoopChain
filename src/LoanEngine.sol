// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICoopVault} from "./interfaces/ICoopVault.sol";
import {ISavings} from "./interfaces/ISavings.sol";
import {ICreditScore} from "./interfaces/ICreditScore.sol";
import {IActuarialEngine} from "./interfaces/IActuarialEngine.sol";

contract LoanEngine {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvalidAddress();
    error MemberInactive();
    error InvalidLoanAmount();
    error NoSavings();
    error LoanAmountTooHigh();
    error InsufficientLiquidity();
    error ActiveLoanExists();
    error RiskTooHigh();
    error LoanNotFound();
    error InvalidAmount();
    error NotLoanBorrower();
    error LoanNotActive();
    error LoanNotPending();
    error LoanAlreadyRepaid();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principal,
        uint256 interestRateBps,
        uint256 duration,
        uint256 totalRepayment
    );

    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);

    event LoanCancelled(uint256 indexed loanId);

    event LoanDefaulted(uint256 indexed loanId);

    /*//////////////////////////////////////////////////////////////
                            ENUMS
    //////////////////////////////////////////////////////////////*/
    enum LoanStatus {
        Pending,
        Active,
        Repaid,
        Defaulted,
        Cancelled
    }

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Loan {
        uint256 loanId;
        address borrower;
        uint256 principal;
        uint256 interestRateBps;
        uint256 duration;
        uint256 totalRepayment;
        uint256 amountRepaid;
        uint256 startDate;
        LoanStatus status;
    }

    struct LoanTerms {
        uint256 principal;
        uint256 interestRateBps;
        uint256 duration;
        uint256 totalRepayment;
    }

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ICoopVault private immutable i_coopVault;
    ISavings private immutable i_savings;
    ICreditScore private immutable i_creditScore;
    IActuarialEngine private immutable i_actuarialEngine;
    IERC20 public immutable i_stableCoin;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant VERY_LOW_RATE_BPS = 500;
    uint256 private constant LOW_RATE_BPS = 700;
    uint256 private constant MEDIUM_RATE_BPS = 1_000;
    uint256 private constant HIGH_RATE_BPS = 1_500;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_nextLoanId;

    mapping(uint256 => Loan) private s_loans;

    mapping(address => uint256[]) private s_memberLoans;

    uint256 private s_totalLoansIssued;

    uint256 private s_totalOutstandingDebt;

    // A member's borrowing capacity is linked to how much they have saved. (Loan-to-Savings policy)
    uint256 private constant MAX_LOAN_MULTIPLE = 3;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Allows an active cooperative member to request and receive a loan.
     *
     * @dev Version 1 lending flow:
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
     *      Calculate repayment terms
     *        |
     *        v
     *      Create loan record
     *        |
     *        v
     *      Update protocol accounting
     *        |
     *        v
     *      Transfer stablecoin
     *
     *      Version 1 decisions:
     *      - Loans are approved immediately after validation.
     *      - Loan status starts as Active.
     *      - No separate approval workflow exists.
     *      - No monthly repayment schedule exists.
     *      - Repayments are flexible partial payments.
     *
     *      Future versions may introduce:
     *      - Pending loan applications.
     *      - Governance/member approval.
     *      - Monthly installments.
     *      - Automated repayment schedules.
     *      - Treasury-based loan disbursement.
     *
     * @param principal Amount of stablecoin requested by the member.
     * @param duration Loan duration used to calculate repayment terms.
     */
    function applyForLoan(uint256 principal, uint256 duration) external {
        _validateMember(msg.sender);

        _validateLoanAmount(msg.sender, principal);

        uint256 interestRateBps = _determineInterestRate(msg.sender);

        LoanTerms memory terms = _calculateLoanTerms(principal, interestRateBps, duration);

        uint256 loanId = _createLoan(msg.sender, terms);

        _recordLoanIssued(terms.totalRepayment);

        i_stableCoin.safeTransfer(msg.sender, principal);

        emit LoanCreated(loanId, msg.sender, principal, interestRateBps, duration, terms.totalRepayment);
    }

    /**
     * @notice Allows a borrower to make a repayment toward an active loan.
     *
     * @dev Version 1 repayment model:
     *
     *      The protocol does not enforce monthly installments.
     *      Borrowers may repay any amount at any time until
     *      the total repayment obligation has been fulfilled.
     *
     *      Repayment flow:
     *
     *      Borrower
     *        |
     *        v
     *      Validate loan ownership and status
     *        |
     *        v
     *      Validate repayment amount
     *        |
     *        v
     *      Transfer stablecoin to protocol
     *        |
     *        v
     *      Update loan repayment balance
     *        |
     *        v
     *      Update protocol debt accounting
     *        |
     *        v
     *      Mark loan as Repaid if fully settled
     *
     *      Example:
     *
     *      Loan repayment = 11,000 USDC
     *
     *      Borrower may repay:
     *      - 2,000 today
     *      - 5,000 next month
     *      - 4,000 later
     *
     *      Once amountRepaid equals totalRepayment,
     *      the loan status changes to Repaid.
     *
     *      Version 1 does not include:
     *      - Monthly payment schedules.
     *      - Due dates.
     *      - Late payment penalties.
     *      - Automated repayment collection.
     *
     *      Future versions may introduce:
     *      - Installment-based repayments.
     *      - Grace periods.
     *      - Credit score updates after repayment.
     *      - Automated payment plans.
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

        i_stableCoin.safeTransferFrom(msg.sender, address(this), amount);

        loan.amountRepaid += amount;

        _recordRepayment(amount);

        if (loan.amountRepaid == loan.totalRepayment) {
            loan.status = LoanStatus.Repaid;
        }

        emit LoanRepaid(loanId, msg.sender, amount);
    }

    /**
     * @notice Marks an overdue loan as defaulted.
     *
     * @dev Version 1 default handling:
     *
     *      Default marking is manual.
     *      The protocol does not yet have:
     *
     *      - Automated keepers.
     *      - Due date tracking.
     *      - Default prediction models.
     *      - Insurance mechanisms.
     *
     *      Future versions may introduce:
     *      - Chainlink Automation/keepers.
     *      - Credit score updates after defaults.
     *      - Recovery mechanisms.
     *      - Insurance pool integration.
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

        loan.status = LoanStatus.Defaulted;

        emit LoanDefaulted(loanId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates that a borrower is an active coop member.
    function _validateMember(address member) internal view returns (ICoopVault.Member memory coopMember) {
        coopMember = i_coopVault.getMember(member);

        if (!coopMember.active) {
            revert MemberInactive();
        }
    }

    /// @notice Validates whether a requested loan amount is eligible.
    function _validateLoanAmount(address borrower, uint256 principal) internal view {
        // Principal must be greater than zero.
        if (principal == 0) {
            revert InvalidLoanAmount();
        }

        // Fetch member savings.
        ISavings.SavingsAccount memory account = i_savings.getSavingsAccount(borrower);

        uint256 savingsBalance = account.balance;

        if (savingsBalance == 0) {
            revert NoSavings();
        }

        // Example lending policy:
        // Maximum loan = 3x member savings.
        if (principal > savingsBalance * MAX_LOAN_MULTIPLE) {
            revert LoanAmountTooHigh();
        }

        // Ensure protocol has sufficient liquidity.
        if (i_stableCoin.balanceOf(address(this)) < principal) {
            revert InsufficientLiquidity();
        }

        // Version 1:
        // Only allow one active loan.
        if (_hasActiveLoan(borrower)) {
            revert ActiveLoanExists();
        }
    }

    /// @notice Determines the borrower's interest rate.
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

    /// @notice Calculates repayment terms using the actuarial engine.
    function _calculateLoanTerms(uint256 principal, uint256 interestRateBps, uint256 duration)
        internal
        view
        returns (LoanTerms memory terms)
    {
        (, uint256 totalRepayment) = i_actuarialEngine.compoundInterest(principal, interestRateBps, duration);

        terms = LoanTerms({
            principal: principal, interestRateBps: interestRateBps, duration: duration, totalRepayment: totalRepayment
        });
    }

    /// @notice Creates and stores a new loan.
    function _createLoan(address borrower, LoanTerms memory terms) internal returns (uint256 loanId) {
        loanId = ++s_nextLoanId;

        s_loans[loanId] = Loan({
            loanId: loanId,
            borrower: borrower,
            principal: terms.principal,
            interestRateBps: terms.interestRateBps,
            duration: terms.duration,
            totalRepayment: terms.totalRepayment,
            amountRepaid: 0,
            startDate: block.timestamp,
            status: LoanStatus.Active
        });

        s_memberLoans[borrower].push(loanId);
    }

    /**
     * @notice Records accounting changes when a new loan is issued.
     * @dev Increments the total number of loans issued and increases
     *      the outstanding debt by the borrower's total repayment obligation.
     * @param totalRepayment The total amount owed by the borrower over the loan duration.
     */
    function _recordLoanIssued(uint256 totalRepayment) internal {
        ++s_totalLoansIssued;
        s_totalOutstandingDebt += totalRepayment;
    }

    /**
     * @notice Records accounting changes when a borrower makes a repayment.
     * @dev Reduces the protocol's outstanding debt by the repayment amount.
     * @param amount The amount repaid by the borrower.
     */
    function _recordRepayment(uint256 amount) internal {
        s_totalOutstandingDebt -= amount;
    }

    /// @notice Returns whether a borrower has an active loan.
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
     *
     * @dev Version 1:
     *      Returns the stored loan information including:
     *      - Principal borrowed.
     *      - Interest rate applied.
     *      - Total repayment amount.
     *      - Amount already repaid.
     *      - Current loan status.
     *
     *      Future versions may include:
     *      - Repayment schedules.
     *      - Next payment date.
     *      - Installment history.
     *
     * @param loanId Identifier of the loan.
     * @return loan Complete loan information.
     */
    function getLoan(uint256 loanId) external view returns (Loan memory loan) {
        if (s_loans[loanId].loanId == 0) {
            revert LoanNotFound();
        }

        return s_loans[loanId];
    }

    /**
     * @notice Returns all loans belonging to a member.
     *
     * @dev Version 1:
     *      Returns only loans created by the borrower.
     *
     *      Future versions may introduce:
     *      - Pagination.
     *      - Filtering by status.
     *      - Historical loan analytics.
     *
     * @param member Address of the cooperative member.
     * @return loans Array containing member loans.
     */
    function getLoansByMember(address member) external view returns (Loan[] memory loans) {
        uint256[] memory loanIds = s_memberLoans[member];

        loans = new Loan[](loanIds.length);

        for (uint256 i = 0; i < loanIds.length; i++) {
            loans[i] = s_loans[loanIds[i]];
        }
    }

    /**
     * @notice Returns total outstanding protocol debt.
     *
     * @dev Version 1:
     *      Tracks total repayment obligations from all active loans.
     *
     *      It increases when:
     *      - A new loan is created.
     *
     *      It decreases when:
     *      - Borrowers make repayments.
     *
     *      Future versions may separate:
     *      - Principal outstanding.
     *      - Interest outstanding.
     *      - Defaulted debt.
     *
     * @return outstandingDebt Total remaining repayment obligation.
     */
    function getOutstandingDebt() external view returns (uint256 outstandingDebt) {
        return s_totalOutstandingDebt;
    }

    /**
     * @notice Returns the total number of loans issued.
     *
     * @dev Version 1:
     *      Counts every created loan.
     *
     *      Future versions may introduce:
     *      - Active loan count.
     *      - Defaulted loan count.
     *      - Repaid loan count.
     *
     * @return totalLoans Number of loans created.
     */
    function getTotalLoansIssued() external view returns (uint256 totalLoans) {
        return s_totalLoansIssued;
    }

    /**
     * @notice Calculates the remaining balance of a loan.
     *
     * @dev Version 1:
     *      Remaining balance is calculated as:
     *
     *      Total Repayment - Amount Repaid
     *
     *      No monthly schedule exists yet.
     *
     *      Future versions may calculate:
     *      - Next installment.
     *      - Interest accrued.
     *      - Late fees.
     *
     * @param loanId Identifier of the loan.
     * @return remainingBalance Amount still owed.
     */
    function getRemainingBalance(uint256 loanId) external view returns (uint256 remainingBalance) {
        Loan memory loan = s_loans[loanId];

        if (loan.loanId == 0) {
            revert LoanNotFound();
        }

        return loan.totalRepayment - loan.amountRepaid;
    }
}
