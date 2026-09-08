// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {LoanEngine} from "../../src/LoanEngine.sol";
import {ArcTreasury} from "../../src/sponsors/Arc/ArcTreasury.sol";

import {ICoopVault} from "../../src/interfaces/ICoopVault.sol";
import {ISavings} from "../../src/interfaces/ISavings.sol";
import {ICreditScore} from "../../src/interfaces/ICreditScore.sol";
import {IActuarialEngine} from "../../src/interfaces/IActuarialEngine.sol";
import {ILoanEngine} from "../../src/interfaces/ILoanEngine.sol";

/**
 * @title LoanEngineTest
 * @author Maxwell Wire
 * @notice Unit tests for the CoopChain LoanEngine contract.
 *
 * @dev Tests cover:
 *      - Constructor validation
 *      - Loan application
 *      - Membership validation
 *      - Savings validation
 *      - Loan-to-savings limits
 *      - Arc Treasury liquidity checks
 *      - Active-loan restrictions
 *      - Risk-based interest rates
 *      - Actuarial loan-term calculation
 *      - Loan accounting
 *      - Loan repayment
 *      - Repayment timing
 *      - Repayment schedules
 *      - Default rules
 *      - View functions
 */
contract LoanEngineTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    LoanEngine private loanEngine;
    ArcTreasury private arcTreasury;
    ERC20Mock private stableCoin;

    address private coopVault = makeAddr("coopVault");
    address private savings = makeAddr("savings");
    address private creditScore = makeAddr("creditScore");
    address private actuarialEngine = makeAddr("actuarialEngine");

    address private borrower = makeAddr("borrower");
    address private borrowerTwo = makeAddr("borrowerTwo");
    address private stranger = makeAddr("stranger");

    /*
     * Arc Testnet USDC address used internally by ArcTreasury.
     *
     * In production this is the real Arc Testnet USDC address.
     * In tests, an ERC20Mock runtime is etched at this address.
     */
    address private constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    uint256 private constant PRINCIPAL = 1_000 ether;
    uint256 private constant DURATION = 12;

    uint256 private constant MONTHLY_PAYMENT = 90 ether;
    uint256 private constant TOTAL_REPAYMENT = 1_080 ether;

    uint256 private constant SAVINGS_BALANCE = 2_000 ether;

    uint256 private constant VERY_LOW_RATE_BPS = 500;
    uint256 private constant LOW_RATE_BPS = 700;
    uint256 private constant MEDIUM_RATE_BPS = 1_000;
    uint256 private constant HIGH_RATE_BPS = 1_500;

    uint256 private constant PAYMENT_INTERVAL = 30 days;
    uint256 private constant DEFAULT_GRACE_PERIOD = 7 days;

    uint256 private constant TREASURY_LIQUIDITY = 1_000_000 ether;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys LoanEngine and Arc Treasury and configures
     *         all dependency mocks.
     *
     * @dev ArcTreasury uses the fixed Arc Testnet USDC address.
     *      Therefore an ERC20Mock runtime is installed at that
     *      address using vm.etch().
     */
    function setUp() public {
        /*
         * Deploy mock USDC implementation.
         */
        ERC20Mock stableCoinImplementation = new ERC20Mock();

        /*
         * Install the ERC20Mock runtime at the Arc Testnet
         * USDC address.
         */
        vm.etch(ARC_TESTNET_USDC, address(stableCoinImplementation).code);

        /*
         * Use the exact token address expected by ArcTreasury.
         */
        stableCoin = ERC20Mock(ARC_TESTNET_USDC);

        /*
         * Deploy ArcTreasury.
         *
         * This test contract becomes the treasury administrator.
         */
        arcTreasury = new ArcTreasury();

        /*
         * Deploy LoanEngine with ArcTreasury as its
         * lending liquidity provider.
         */
        loanEngine =
            new LoanEngine(coopVault, savings, creditScore, actuarialEngine, ARC_TESTNET_USDC, address(arcTreasury));

        /*
         * Authorize LoanEngine to release funds from ArcTreasury.
         */
        arcTreasury.setOperatorAuthorization(address(loanEngine), true);

        /*
         * Fund treasury with sufficient liquidity.
         */
        stableCoin.mint(address(arcTreasury), TREASURY_LIQUIDITY);

        /*
         * Default borrower configuration.
         */
        _mockActiveMember(borrower);
        _mockSavings(borrower, SAVINGS_BALANCE);
        _mockRiskTier(borrower, ICreditScore.RiskTier.VeryLow);

        /*
         * Default actuarial terms.
         */
        _mockLoanTerms(PRINCIPAL, VERY_LOW_RATE_BPS, DURATION, MONTHLY_PAYMENT, TOTAL_REPAYMENT);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_CoopVaultIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(address(0), savings, creditScore, actuarialEngine, address(stableCoin), address(arcTreasury));
    }

    function test_RevertWhen_SavingsIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, address(0), creditScore, actuarialEngine, address(stableCoin), address(arcTreasury));
    }

    function test_RevertWhen_CreditScoreIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, address(0), actuarialEngine, address(stableCoin), address(arcTreasury));
    }

    function test_RevertWhen_ActuarialEngineIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, creditScore, address(0), address(stableCoin), address(arcTreasury));
    }

    function test_RevertWhen_StableCoinIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, creditScore, actuarialEngine, address(0), address(arcTreasury));
    }

    function test_RevertWhen_ArcTreasuryIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, creditScore, actuarialEngine, address(stableCoin), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN APPLICATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApplyForLoan_CreatesLoan() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.loanId, 1);
        assertEq(loan.borrower, borrower);
        assertEq(loan.principal, PRINCIPAL);
        assertEq(loan.interestRateBps, VERY_LOW_RATE_BPS);
        assertEq(loan.duration, DURATION);
        assertEq(loan.monthlyPayment, MONTHLY_PAYMENT);
        assertEq(loan.totalRepayment, TOTAL_REPAYMENT);
        assertEq(loan.amountRepaid, 0);

        assertEq(loan.nextDueDate, loan.startDate + PAYMENT_INTERVAL);

        assertEq(uint256(loan.status), uint256(ILoanEngine.LoanStatus.Active));
    }

    function test_ApplyForLoan_TransfersPrincipal() public {
        uint256 balanceBefore = stableCoin.balanceOf(borrower);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        uint256 balanceAfter = stableCoin.balanceOf(borrower);

        assertEq(balanceAfter - balanceBefore, PRINCIPAL);
    }

    function test_ApplyForLoan_IncrementsTotalLoansIssued() public {
        assertEq(loanEngine.getTotalLoansIssued(), 0);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getTotalLoansIssued(), 1);
    }

    function test_ApplyForLoan_RecordsOutstandingDebt() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT);
    }

    function test_ApplyForLoan_EmitsLoanCreated() public {
        vm.expectEmit(true, true, false, true);

        emit ILoanEngine.LoanCreated(
            1,
            borrower,
            PRINCIPAL,
            VERY_LOW_RATE_BPS,
            DURATION,
            MONTHLY_PAYMENT,
            TOTAL_REPAYMENT,
            block.timestamp + PAYMENT_INTERVAL
        );

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    function test_ApplyForLoan_ConsumesTreasuryLiquidity() public {
        uint256 treasuryBalanceBefore = arcTreasury.getBalance();

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(arcTreasury.getBalance(), treasuryBalanceBefore - PRINCIPAL);
    }

    /*//////////////////////////////////////////////////////////////
                    MEMBERSHIP VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_MemberIsInactive() public {
        _mockInactiveMember(borrower);

        vm.expectRevert(ILoanEngine.MemberInactive.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN AMOUNT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_PrincipalIsZero() public {
        vm.expectRevert(ILoanEngine.InvalidLoanAmount.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(0, DURATION);
    }

    function test_RevertWhen_MemberHasNoSavings() public {
        _mockSavings(borrower, 0);

        vm.expectRevert(ILoanEngine.NoSavings.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    function test_RevertWhen_LoanExceedsThreeTimesSavings() public {
        uint256 savingsBalance = 1_000 ether;

        _mockSavings(borrower, savingsBalance);

        uint256 maximumLoan = savingsBalance * 3;

        uint256 excessiveLoan = maximumLoan + 1;

        vm.expectRevert(ILoanEngine.LoanAmountTooHigh.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(excessiveLoan, DURATION);
    }

    function test_ApplyForLoan_ExactlyThreeTimesSavings() public {
        uint256 savingsBalance = 1_000 ether;

        uint256 maximumLoan = savingsBalance * 3;

        _mockSavings(borrower, savingsBalance);

        _mockLoanTerms(maximumLoan, VERY_LOW_RATE_BPS, DURATION, 270 ether, 3_240 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(maximumLoan, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.principal, maximumLoan);

        assertEq(loan.interestRateBps, VERY_LOW_RATE_BPS);
    }

    function test_RevertWhen_InsufficientLiquidity() public {
        uint256 currentLiquidity = arcTreasury.getBalance();

        arcTreasury.withdraw(address(this), currentLiquidity);

        assertEq(arcTreasury.getBalance(), 0);

        vm.expectRevert(ILoanEngine.InsufficientLiquidity.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    function test_RevertWhen_ActiveLoanAlreadyExists() public {
        vm.startPrank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        vm.expectRevert(ILoanEngine.ActiveLoanExists.selector);

        loanEngine.applyForLoan(100 ether, DURATION);

        vm.stopPrank();
    }

    function test_RevertWhen_DurationIsZero() public {
        vm.expectRevert(ILoanEngine.InvalidDuration.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    RISK TIER / INTEREST RATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InterestRate_VeryLow() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.VeryLow);

        _mockLoanTerms(PRINCIPAL, VERY_LOW_RATE_BPS, DURATION, MONTHLY_PAYMENT, TOTAL_REPAYMENT);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, VERY_LOW_RATE_BPS);
    }

    function test_InterestRate_Low() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.Low);

        _mockLoanTerms(PRINCIPAL, LOW_RATE_BPS, DURATION, 95 ether, 1_140 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, LOW_RATE_BPS);
    }

    function test_InterestRate_Medium() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.Medium);

        _mockLoanTerms(PRINCIPAL, MEDIUM_RATE_BPS, DURATION, 100 ether, 1_200 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, MEDIUM_RATE_BPS);
    }

    function test_InterestRate_High() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.High);

        _mockLoanTerms(PRINCIPAL, HIGH_RATE_BPS, DURATION, 105 ether, 1_260 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, HIGH_RATE_BPS);
    }

    function test_RevertWhen_RiskIsTooHigh() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.VeryHigh);

        vm.expectRevert(ILoanEngine.RiskTooHigh.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                        LOAN VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetLoan_ReturnsCorrectLoan() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.loanId, 1);
        assertEq(loan.borrower, borrower);
        assertEq(loan.principal, PRINCIPAL);
    }

    function test_RevertWhen_GetLoanDoesNotExist() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.getLoan(999);
    }

    function test_GetLoansByMember_ReturnsLoans() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan[] memory loans = loanEngine.getLoansByMember(borrower);

        assertEq(loans.length, 1);
        assertEq(loans[0].loanId, 1);
        assertEq(loans[0].borrower, borrower);
    }

    function test_GetLoansByMember_IsIndependent() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        _mockActiveMember(borrowerTwo);
        _mockSavings(borrowerTwo, SAVINGS_BALANCE);
        _mockRiskTier(borrowerTwo, ICreditScore.RiskTier.VeryLow);

        vm.prank(borrowerTwo);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan[] memory firstLoans = loanEngine.getLoansByMember(borrower);

        ILoanEngine.Loan[] memory secondLoans = loanEngine.getLoansByMember(borrowerTwo);

        assertEq(firstLoans.length, 1);
        assertEq(secondLoans.length, 1);

        assertEq(firstLoans[0].loanId, 1);

        assertEq(secondLoans[0].loanId, 2);
    }

    function test_GetTotalLoansIssued() public {
        assertEq(loanEngine.getTotalLoansIssued(), 0);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getTotalLoansIssued(), 1);
    }

    function test_GetOutstandingDebt() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT);
    }

    function test_GetRemainingBalance_BeforeRepayment() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getRemainingBalance(1), TOTAL_REPAYMENT);
    }

    function test_GetRemainingBalance_AfterRepayment() public {
        _prepareRepayment();

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        assertEq(loanEngine.getRemainingBalance(1), TOTAL_REPAYMENT - MONTHLY_PAYMENT);
    }

    function test_RevertWhen_GetRemainingBalanceDoesNotExist() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.getRemainingBalance(999);
    }

    /*//////////////////////////////////////////////////////////////
                        REPAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_RepaymentBeforeDueDate() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        stableCoin.mint(borrower, MONTHLY_PAYMENT);

        vm.startPrank(borrower);

        stableCoin.approve(address(loanEngine), MONTHLY_PAYMENT);

        vm.expectRevert(ILoanEngine.PaymentNotDue.selector);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        vm.stopPrank();
    }

    function test_RepayLoan_UpdatesAmountRepaid() public {
        _prepareRepayment();

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.amountRepaid, MONTHLY_PAYMENT);
    }

    function test_RepayLoan_ReducesOutstandingDebt() public {
        _prepareRepayment();

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT - MONTHLY_PAYMENT);
    }

    function test_RepayLoan_TransfersTokensToTreasury() public {
        _prepareRepayment();

        uint256 treasuryBalanceBefore = arcTreasury.getBalance();

        vm.startPrank(borrower);

        stableCoin.approve(address(loanEngine), MONTHLY_PAYMENT);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        vm.stopPrank();

        assertEq(arcTreasury.getBalance(), treasuryBalanceBefore + MONTHLY_PAYMENT);

        assertEq(stableCoin.balanceOf(address(loanEngine)), 0);
    }

    function test_RepayLoan_AdvancesNextDueDate() public {
        _prepareRepayment();

        ILoanEngine.Loan memory beforeLoan = loanEngine.getLoan(1);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        ILoanEngine.Loan memory afterLoan = loanEngine.getLoan(1);

        assertEq(afterLoan.nextDueDate, beforeLoan.nextDueDate + PAYMENT_INTERVAL);
    }

    function test_RevertWhen_RepaymentAmountIsZero() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.InvalidAmount.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, 0);
    }

    function test_RevertWhen_RepaymentExceedsRemainingBalance() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.InvalidAmount.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, TOTAL_REPAYMENT + 1);
    }

    function test_RevertWhen_RepaymentDoesNotMatchSchedule() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.InvalidAmount.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT - 1);
    }

    function test_RevertWhen_RepayingNonexistentLoan() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(999, MONTHLY_PAYMENT);
    }

    function test_RevertWhen_NotLoanBorrowerRepays() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.NotLoanBorrower.selector);

        vm.prank(stranger);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);
    }

    function test_RevertWhen_RepayingInactiveLoan() public {
        _prepareRepayment();

        vm.prank(borrower);
        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        /*
         * The first repayment advances nextDueDate by
         * PAYMENT_INTERVAL. Warp to that date before making
         * the final repayment.
         */
        _repayRemaining();

        vm.expectRevert(ILoanEngine.LoanNotActive.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);
    }

    function test_RepayLoan_FinalPaymentMarksLoanRepaid() public {
        _prepareRepayment();

        vm.prank(borrower);
        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        _repayRemaining();

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.amountRepaid, TOTAL_REPAYMENT);

        assertEq(uint256(loan.status), uint256(ILoanEngine.LoanStatus.Repaid));
    }

    function test_RepayLoan_FinalPaymentCanBeRemainingBalance() public {
        _prepareRepayment();

        vm.prank(borrower);
        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        _repayRemaining();

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.amountRepaid, loan.totalRepayment);

        assertEq(uint256(loan.status), uint256(ILoanEngine.LoanStatus.Repaid));

        assertEq(loanEngine.getRemainingBalance(1), 0);
    }

    function test_RepayLoan_EmitsLoanRepaid() public {
        _prepareRepayment();

        vm.expectEmit(true, true, false, true);

        emit ILoanEngine.LoanRepaid(1, borrower, MONTHLY_PAYMENT);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);
    }

    /*//////////////////////////////////////////////////////////////
                    REPAYMENT SCHEDULE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetRepaymentSchedule_ReturnsCorrectLength() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (uint256[] memory dueDates, uint256[] memory payments) = loanEngine.getRepaymentSchedule(1);

        assertEq(dueDates.length, DURATION);

        assertEq(payments.length, DURATION);
    }

    function test_GetRepaymentSchedule_DatesIncreaseBy30Days() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (uint256[] memory dueDates,) = loanEngine.getRepaymentSchedule(1);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        for (uint256 i = 0; i < dueDates.length; ++i) {
            assertEq(dueDates[i], loan.startDate + ((i + 1) * PAYMENT_INTERVAL));
        }
    }

    function test_GetRepaymentSchedule_ReturnsMonthlyPayments() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (, uint256[] memory payments) = loanEngine.getRepaymentSchedule(1);

        for (uint256 i = 0; i < payments.length - 1; ++i) {
            assertEq(payments[i], MONTHLY_PAYMENT);
        }
    }

    function test_GetRepaymentSchedule_FinalPaymentCompletesTotal() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (, uint256[] memory payments) = loanEngine.getRepaymentSchedule(1);

        uint256 totalScheduled;

        for (uint256 i = 0; i < payments.length; ++i) {
            totalScheduled += payments[i];
        }

        assertEq(totalScheduled, TOTAL_REPAYMENT);
    }

    function test_GetRepaymentSchedule_FinalPaymentMatchesRemaining() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (, uint256[] memory payments) = loanEngine.getRepaymentSchedule(1);

        uint256 expectedFinalPayment = TOTAL_REPAYMENT - (MONTHLY_PAYMENT * (DURATION - 1));

        assertEq(payments[DURATION - 1], expectedFinalPayment);
    }

    function test_RevertWhen_ScheduleLoanDoesNotExist() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.getRepaymentSchedule(999);
    }

    /*//////////////////////////////////////////////////////////////
                            DEFAULT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_DefaultCalledDuringGracePeriod() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        vm.warp(loan.nextDueDate + DEFAULT_GRACE_PERIOD);

        vm.expectRevert(ILoanEngine.PaymentNotDue.selector);

        loanEngine.markDefaulted(1);
    }

    function test_MarkDefaulted_AfterGracePeriod() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        vm.warp(loan.nextDueDate + DEFAULT_GRACE_PERIOD + 1);

        loanEngine.markDefaulted(1);

        loan = loanEngine.getLoan(1);

        assertEq(uint256(loan.status), uint256(ILoanEngine.LoanStatus.Defaulted));
    }

    function test_RevertWhen_DefaultingNonexistentLoan() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.markDefaulted(999);
    }

    function test_RevertWhen_DefaultingBeforeDueDate() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        vm.expectRevert(ILoanEngine.PaymentNotDue.selector);

        loanEngine.markDefaulted(1);
    }

    function test_RevertWhen_DefaultingRepaidLoan() public {
        _prepareRepayment();

        vm.prank(borrower);
        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        /*
         * Complete the loan at its second scheduled payment date.
         */
        _repayRemaining();

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        /*
         * A repaid loan should remain inactive regardless of how
         * far the blockchain timestamp is advanced.
         */
        vm.warp(loan.nextDueDate + DEFAULT_GRACE_PERIOD + 1);

        vm.expectRevert(ILoanEngine.LoanNotActive.selector);

        loanEngine.markDefaulted(1);
    }

    function test_MarkDefaulted_EmitsEvent() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        vm.warp(loan.nextDueDate + DEFAULT_GRACE_PERIOD + 1);

        vm.expectEmit(true, false, false, false);

        emit ILoanEngine.LoanDefaulted(1);

        loanEngine.markDefaulted(1);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-LOAN / ACCOUNTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_LoanIdsIncrementSequentially() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        _mockActiveMember(borrowerTwo);
        _mockSavings(borrowerTwo, SAVINGS_BALANCE);
        _mockRiskTier(borrowerTwo, ICreditScore.RiskTier.VeryLow);

        vm.prank(borrowerTwo);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getLoan(1).loanId, 1);

        assertEq(loanEngine.getLoan(2).loanId, 2);
    }

    function test_OutstandingDebt_AccumulatesAcrossLoans() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        _mockActiveMember(borrowerTwo);
        _mockSavings(borrowerTwo, SAVINGS_BALANCE);
        _mockRiskTier(borrowerTwo, ICreditScore.RiskTier.VeryLow);

        vm.prank(borrowerTwo);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT * 2);
    }

    function test_Repayment_OnlyUpdatesBorrowersLoan() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        _mockActiveMember(borrowerTwo);
        _mockSavings(borrowerTwo, SAVINGS_BALANCE);
        _mockRiskTier(borrowerTwo, ICreditScore.RiskTier.VeryLow);

        vm.prank(borrowerTwo);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        stableCoin.mint(borrower, MONTHLY_PAYMENT);

        vm.warp(loanEngine.getLoan(1).nextDueDate);

        vm.startPrank(borrower);

        stableCoin.approve(address(loanEngine), MONTHLY_PAYMENT);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        vm.stopPrank();

        assertEq(loanEngine.getLoan(1).amountRepaid, MONTHLY_PAYMENT);

        assertEq(loanEngine.getLoan(2).amountRepaid, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ValidLoanAmount(uint256 principal) public {
        principal = bound(principal, 1 ether, SAVINGS_BALANCE * 3);

        _mockLoanTerms(principal, VERY_LOW_RATE_BPS, DURATION, MONTHLY_PAYMENT, TOTAL_REPAYMENT);

        vm.prank(borrower);

        loanEngine.applyForLoan(principal, DURATION);

        assertEq(loanEngine.getLoan(1).principal, principal);
    }

    function testFuzz_LoanAmountAboveLimitReverts(uint256 principal) public {
        principal = bound(principal, SAVINGS_BALANCE * 3 + 1, type(uint128).max);

        vm.expectRevert(ILoanEngine.LoanAmountTooHigh.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(principal, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Repays the remaining balance of loan #1.
     *
     * @dev The first repayment advances nextDueDate by
     * PAYMENT_INTERVAL. Therefore the test must warp to
     * the updated due date before making the final payment.
     */
    function _repayRemaining() internal {
        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);
        uint256 remaining = loan.totalRepayment - loan.amountRepaid;
        vm.warp(loan.nextDueDate);
        vm.prank(borrower);
        loanEngine.repayLoan(1, remaining);
    }

    /**
     * @notice Prepares a borrower and loan for repayment tests.
     *
     * @dev The blockchain timestamp is advanced to the loan's
     *      first scheduled payment date so repayLoan() can
     *      execute successfully.
     */
    function _prepareRepayment() internal {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        /*
         * Move time to the first scheduled payment date.
         */
        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        vm.warp(loan.nextDueDate);

        /*
         * Fund borrower for repayment.
         */
        stableCoin.mint(borrower, TOTAL_REPAYMENT);

        /*
         * Approve LoanEngine as ERC20 spender.
         *
         * LoanEngine then transfers the repayment directly
         * into ArcTreasury.
         */
        vm.prank(borrower);

        stableCoin.approve(address(loanEngine), TOTAL_REPAYMENT);
    }

    /**
     * @notice Mocks an active CoopChain member.
     */
    function _mockActiveMember(address member) internal {
        ICoopVault.Member memory coopMember;

        coopMember.active = true;

        vm.mockCall(coopVault, abi.encodeWithSelector(ICoopVault.getMember.selector, member), abi.encode(coopMember));
    }

    /**
     * @notice Mocks an inactive CoopChain member.
     */
    function _mockInactiveMember(address member) internal {
        ICoopVault.Member memory coopMember;

        coopMember.active = false;

        vm.mockCall(coopVault, abi.encodeWithSelector(ICoopVault.getMember.selector, member), abi.encode(coopMember));
    }

    /**
     * @notice Mocks a member savings balance.
     */
    function _mockSavings(address member, uint256 balance) internal {
        ISavings.SavingsAccount memory account;

        account.balance = balance;

        vm.mockCall(savings, abi.encodeWithSelector(ISavings.getSavingsAccount.selector, member), abi.encode(account));
    }

    /**
     * @notice Mocks a member's credit risk tier.
     */
    function _mockRiskTier(address member, ICreditScore.RiskTier riskTier) internal {
        vm.mockCall(
            creditScore, abi.encodeWithSelector(ICreditScore.getRiskTier.selector, member), abi.encode(riskTier)
        );
    }

    /**
     * @notice Mocks actuarial loan-term calculation.
     */
    function _mockLoanTerms(
        uint256 principal,
        uint256 interestRateBps,
        uint256 duration,
        uint256 monthlyPayment,
        uint256 totalRepayment
    ) internal {
        vm.mockCall(
            actuarialEngine,
            abi.encodeWithSelector(
                IActuarialEngine.calculateMonthlyPayment.selector, principal, interestRateBps, duration
            ),
            abi.encode(monthlyPayment, totalRepayment)
        );
    }
}
