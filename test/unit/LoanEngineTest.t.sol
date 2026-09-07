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
 *
 * @title LoanEngineTest
 * @author Maxwell Wire
 * @notice Unit tests for the CoopChain LoanEngine contract.
 *
 * @dev Tests cover:
 * ```
 *    - Constructor validation
 *   ```
 * ```
 *    - Loan application
 *   ```
 * ```
 *    - Membership validation
 *   ```
 * ```
 *    - Savings validation
 *   ```
 * ```
 *    - Loan-to-savings limits
 *   ```
 * ```
 *    - Arc Treasury liquidity checks
 *   ```
 * ```
 *    - Active-loan restrictions
 *   ```
 * ```
 *    - Risk-based interest rates
 *   ```
 * ```
 *    - Actuarial loan-term calculation
 *   ```
 * ```
 *    - Loan accounting
 *   ```
 * ```
 *    - Loan repayment
 *   ```
 * ```
 *    - Repayment schedules
 *   ```
 * ```
 *    - Default rules
 *   ```
 * ```
 *    - View functions
 *   ```
 *
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
     *         dependency mocks.
     *
     * @dev
     * ArcTreasury uses a fixed Arc Testnet USDC address rather than
     * receiving the token address through its constructor.
     *
     * Therefore the ERC20Mock runtime is installed at the Arc USDC
     * address using vm.etch() so the treasury and LoanEngine operate
     * against the same token in the unit tests.
     */
    function setUp() public {
        /*
         * Deploy the mock stablecoin implementation.
         */
        ERC20Mock stableCoinImplementation = new ERC20Mock();

        /*
         * Install the ERC20Mock runtime at the Arc Testnet USDC
         * address used internally by ArcTreasury.
         */
        vm.etch(ARC_TESTNET_USDC, address(stableCoinImplementation).code);

        /*
         * Point the test token reference at the exact address used
         * by ArcTreasury.
         */
        stableCoin = ERC20Mock(ARC_TESTNET_USDC);

        /*
         * Deploy the Arc Treasury.
         *
         * The test contract becomes the treasury administrator.
         */
        arcTreasury = new ArcTreasury();

        /*
         * Deploy LoanEngine with the Arc Treasury as its
         * settlement and liquidity provider.
         */
        loanEngine =
            new LoanEngine(coopVault, savings, creditScore, actuarialEngine, ARC_TESTNET_USDC, address(arcTreasury));

        /*
         * Authorize LoanEngine as an Arc Treasury operator.
         *
         * This allows LoanEngine to call release() when
         * disbursing loan principals.
         */
        arcTreasury.setOperatorAuthorization(address(loanEngine), true);

        /*
         * Fund the Arc Treasury with sufficient stablecoin
         * liquidity for loan disbursement tests.
         *
         * The mock is now running at the same address used by
         * ArcTreasury, so minting directly to the treasury works.
         */
        stableCoin.mint(address(arcTreasury), TREASURY_LIQUIDITY);

        /*
         * Default borrower configuration.
         *
         * These mock calls are overridden in individual tests
         * whenever a different behavior is required.
         */
        _mockActiveMember(borrower);
        _mockSavings(borrower, SAVINGS_BALANCE);
        _mockRiskTier(borrower, ICreditScore.RiskTier.VeryLow);

        /*
         * Mock the actuarial engine.
         */
        _mockLoanTerms(PRINCIPAL, VERY_LOW_RATE_BPS, DURATION, MONTHLY_PAYMENT, TOTAL_REPAYMENT);
    }

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ensures the constructor rejects a zero CoopVault address.
     */
    function test_RevertWhen_CoopVaultIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(address(0), savings, creditScore, actuarialEngine, address(stableCoin), address(arcTreasury));
    }

    /**
     * @notice Ensures the constructor rejects a zero Savings address.
     */
    function test_RevertWhen_SavingsIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, address(0), creditScore, actuarialEngine, address(stableCoin), address(arcTreasury));
    }

    /**
     * @notice Ensures the constructor rejects a zero CreditScore address.
     */
    function test_RevertWhen_CreditScoreIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, address(0), actuarialEngine, address(stableCoin), address(arcTreasury));
    }

    /**
     * @notice Ensures the constructor rejects a zero ActuarialEngine address.
     */
    function test_RevertWhen_ActuarialEngineIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, creditScore, address(0), address(stableCoin), address(arcTreasury));
    }

    /**
     * @notice Ensures the constructor rejects a zero stablecoin address.
     */
    function test_RevertWhen_StableCoinIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, creditScore, actuarialEngine, address(0), address(arcTreasury));
    }

    /**
     * @notice Ensures the constructor rejects a zero Arc Treasury address.
     */
    function test_RevertWhen_ArcTreasuryIsZeroAddress() public {
        vm.expectRevert(ILoanEngine.InvalidAddress.selector);

        new LoanEngine(coopVault, savings, creditScore, actuarialEngine, address(stableCoin), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN APPLICATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that an eligible member can create a loan.
     */
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

    /**
     * @notice Verifies that the borrower receives the loan principal.
     */
    function test_ApplyForLoan_TransfersPrincipal() public {
        uint256 balanceBefore = stableCoin.balanceOf(borrower);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        uint256 balanceAfter = stableCoin.balanceOf(borrower);

        assertEq(balanceAfter - balanceBefore, PRINCIPAL);
    }

    /**
     * @notice Verifies that the total number of issued loans increases.
     */
    function test_ApplyForLoan_IncrementsTotalLoansIssued() public {
        assertEq(loanEngine.getTotalLoansIssued(), 0);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getTotalLoansIssued(), 1);
    }

    /**
     * @notice Verifies outstanding debt is recorded using total repayment.
     */
    function test_ApplyForLoan_RecordsOutstandingDebt() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT);
    }

    /**
     * @notice Verifies the LoanCreated event.
     */
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

    /**
     * @notice Verifies loan disbursement consumes Arc Treasury liquidity.
     */
    function test_ApplyForLoan_ConsumesTreasuryLiquidity() public {
        uint256 treasuryBalanceBefore = arcTreasury.getBalance();

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(arcTreasury.getBalance(), treasuryBalanceBefore - PRINCIPAL);
    }

    /*//////////////////////////////////////////////////////////////
                    MEMBERSHIP VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies inactive members cannot apply for loans.
     */
    function test_RevertWhen_MemberIsInactive() public {
        _mockInactiveMember(borrower);

        vm.expectRevert(ILoanEngine.MemberInactive.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN AMOUNT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies zero principal is rejected.
     */
    function test_RevertWhen_PrincipalIsZero() public {
        vm.expectRevert(ILoanEngine.InvalidLoanAmount.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(0, DURATION);
    }

    /**
     * @notice Verifies members with zero savings cannot borrow.
     */
    function test_RevertWhen_MemberHasNoSavings() public {
        _mockSavings(borrower, 0);

        vm.expectRevert(ILoanEngine.NoSavings.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    /**
     * @notice Verifies that a loan exceeding three times the member's
     *         savings balance is rejected.
     */
    function test_RevertWhen_LoanExceedsThreeTimesSavings() public {
        uint256 savingsBalance = 1_000 ether;

        _mockSavings(borrower, savingsBalance);

        uint256 maximumLoan = savingsBalance * 3;
        uint256 excessiveLoan = maximumLoan + 1;

        vm.expectRevert(ILoanEngine.LoanAmountTooHigh.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(excessiveLoan, DURATION);
    }

    /**
     * @notice Verifies that a member can borrow exactly three times
     *         their savings balance.
     */
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

    /**
     * @notice Verifies insufficient Arc Treasury liquidity prevents lending.
     */
    function test_RevertWhen_InsufficientLiquidity() public {
        uint256 currentLiquidity = arcTreasury.getBalance();

        /*
         * Remove all treasury liquidity through the treasury
         * administrator.
         */
        arcTreasury.withdraw(address(this), currentLiquidity);

        assertEq(arcTreasury.getBalance(), 0);

        vm.expectRevert(ILoanEngine.InsufficientLiquidity.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    /**
     * @notice Verifies a borrower cannot have two active loans.
     */
    function test_RevertWhen_ActiveLoanAlreadyExists() public {
        vm.startPrank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        vm.expectRevert(ILoanEngine.ActiveLoanExists.selector);

        loanEngine.applyForLoan(100 ether, DURATION);

        vm.stopPrank();
    }

    /**
     * @notice Verifies zero duration is rejected.
     */
    function test_RevertWhen_DurationIsZero() public {
        vm.expectRevert(ILoanEngine.InvalidDuration.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    RISK TIER / INTEREST RATE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies VeryLow risk receives a 5% rate.
     */
    function test_InterestRate_VeryLow() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.VeryLow);

        _mockLoanTerms(PRINCIPAL, VERY_LOW_RATE_BPS, DURATION, MONTHLY_PAYMENT, TOTAL_REPAYMENT);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, VERY_LOW_RATE_BPS);
    }

    /**
     * @notice Verifies Low risk receives a 7% rate.
     */
    function test_InterestRate_Low() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.Low);

        _mockLoanTerms(PRINCIPAL, LOW_RATE_BPS, DURATION, 95 ether, 1_140 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, LOW_RATE_BPS);
    }

    /**
     * @notice Verifies Medium risk receives a 10% rate.
     */
    function test_InterestRate_Medium() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.Medium);

        _mockLoanTerms(PRINCIPAL, MEDIUM_RATE_BPS, DURATION, 100 ether, 1_200 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, MEDIUM_RATE_BPS);
    }

    /**
     * @notice Verifies High risk receives a 15% rate.
     */
    function test_InterestRate_High() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.High);

        _mockLoanTerms(PRINCIPAL, HIGH_RATE_BPS, DURATION, 105 ether, 1_260 ether);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.interestRateBps, HIGH_RATE_BPS);
    }

    /**
     * @notice Verifies the highest risk tier is rejected.
     */
    function test_RevertWhen_RiskIsTooHigh() public {
        _mockRiskTier(borrower, ICreditScore.RiskTier.VeryHigh);

        vm.expectRevert(ILoanEngine.RiskTooHigh.selector);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);
    }

    /*//////////////////////////////////////////////////////////////
                        LOAN VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies getLoan returns the stored loan.
     */
    function test_GetLoan_ReturnsCorrectLoan() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.loanId, 1);
        assertEq(loan.borrower, borrower);
        assertEq(loan.principal, PRINCIPAL);
    }

    /**
     * @notice Verifies requesting a nonexistent loan reverts.
     */
    function test_RevertWhen_GetLoanDoesNotExist() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.getLoan(999);
    }

    /**
     * @notice Verifies getLoansByMember returns the member's loans.
     */
    function test_GetLoansByMember_ReturnsLoans() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan[] memory loans = loanEngine.getLoansByMember(borrower);

        assertEq(loans.length, 1);
        assertEq(loans[0].loanId, 1);
        assertEq(loans[0].borrower, borrower);
    }

    /**
     * @notice Verifies members have independent loan records.
     */
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

    /**
     * @notice Verifies getTotalLoansIssued returns the correct count.
     */
    function test_GetTotalLoansIssued() public {
        assertEq(loanEngine.getTotalLoansIssued(), 0);

        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getTotalLoansIssued(), 1);
    }

    /**
     * @notice Verifies getOutstandingDebt returns the current debt.
     */
    function test_GetOutstandingDebt() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT);
    }

    /**
     * @notice Verifies getRemainingBalance returns total repayment
     *         before any repayments are made.
     */
    function test_GetRemainingBalance_BeforeRepayment() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        assertEq(loanEngine.getRemainingBalance(1), TOTAL_REPAYMENT);
    }

    /**
     * @notice Verifies getRemainingBalance is reduced after repayment.
     */
    function test_GetRemainingBalance_AfterRepayment() public {
        _prepareRepayment();

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        assertEq(loanEngine.getRemainingBalance(1), TOTAL_REPAYMENT - MONTHLY_PAYMENT);
    }

    /**
     * @notice Verifies getRemainingBalance reverts for nonexistent loans.
     */
    function test_RevertWhen_GetRemainingBalanceDoesNotExist() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.getRemainingBalance(999);
    }

    /*//////////////////////////////////////////////////////////////
                    REPAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies a borrower can make a scheduled repayment.
     */
    function test_RepayLoan_UpdatesAmountRepaid() public {
        _prepareRepayment();

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.amountRepaid, MONTHLY_PAYMENT);
    }

    /**
     * @notice Verifies repayment reduces outstanding protocol debt.
     */
    function test_RepayLoan_ReducesOutstandingDebt() public {
        _prepareRepayment();

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        assertEq(loanEngine.getOutstandingDebt(), TOTAL_REPAYMENT - MONTHLY_PAYMENT);
    }

    /**
     * @notice Verifies repayment transfers stablecoins into Arc Treasury.
     */
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

    /**
     * @notice Verifies repayment advances the next due date by 30 days.
     */
    function test_RepayLoan_AdvancesNextDueDate() public {
        _prepareRepayment();

        ILoanEngine.Loan memory beforeLoan = loanEngine.getLoan(1);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        ILoanEngine.Loan memory afterLoan = loanEngine.getLoan(1);

        assertEq(afterLoan.nextDueDate, beforeLoan.nextDueDate + PAYMENT_INTERVAL);
    }

    /**
     * @notice Verifies a zero repayment amount is rejected.
     */
    function test_RevertWhen_RepaymentAmountIsZero() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.InvalidAmount.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, 0);
    }

    /**
     * @notice Verifies repayments larger than the remaining balance
     *         are rejected.
     */
    function test_RevertWhen_RepaymentExceedsRemainingBalance() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.InvalidAmount.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, TOTAL_REPAYMENT + 1);
    }

    /**
     * @notice Verifies arbitrary partial installments are rejected.
     */
    function test_RevertWhen_RepaymentDoesNotMatchSchedule() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.InvalidAmount.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT - 1);
    }

    /**
     * @notice Verifies nonexistent loans cannot be repaid.
     */
    function test_RevertWhen_RepayingNonexistentLoan() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(999, MONTHLY_PAYMENT);
    }

    /**
     * @notice Verifies only the borrower can repay their loan.
     */
    function test_RevertWhen_NotLoanBorrowerRepays() public {
        _prepareRepayment();

        vm.expectRevert(ILoanEngine.NotLoanBorrower.selector);

        vm.prank(stranger);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);
    }

    /**
     * @notice Verifies repayments can only be made on active loans.
     */
    function test_RevertWhen_RepayingInactiveLoan() public {
        _prepareRepayment();

        vm.startPrank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        uint256 remaining = loanEngine.getRemainingBalance(1);

        stableCoin.approve(address(loanEngine), remaining);

        loanEngine.repayLoan(1, remaining);

        vm.stopPrank();

        vm.expectRevert(ILoanEngine.LoanNotActive.selector);

        vm.prank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);
    }

    /**
     * @notice Verifies a fully repaid loan is marked as Repaid.
     */
    function test_RepayLoan_FinalPaymentMarksLoanRepaid() public {
        _prepareRepayment();

        vm.startPrank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        uint256 remaining = loanEngine.getRemainingBalance(1);

        stableCoin.approve(address(loanEngine), remaining);

        loanEngine.repayLoan(1, remaining);

        vm.stopPrank();

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        assertEq(loan.amountRepaid, TOTAL_REPAYMENT);

        assertEq(uint256(loan.status), uint256(ILoanEngine.LoanStatus.Repaid));
    }

    /**
     * @notice Verifies the final repayment can be smaller than
     *         monthlyPayment.
     */
    function test_RepayLoan_FinalPaymentCanBeRemainingBalance() public {
        _prepareRepayment();

        vm.startPrank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        uint256 remaining = loanEngine.getRemainingBalance(1);

        stableCoin.approve(address(loanEngine), remaining);

        loanEngine.repayLoan(1, remaining);

        vm.stopPrank();

        assertEq(loanEngine.getRemainingBalance(1), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    REPAYMENT SCHEDULE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies the repayment schedule has the expected
     *         number of installments.
     */
    function test_GetRepaymentSchedule_ReturnsCorrectLength() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (uint256[] memory dueDates, uint256[] memory payments) = loanEngine.getRepaymentSchedule(1);

        assertEq(dueDates.length, DURATION);
        assertEq(payments.length, DURATION);
    }

    /**
     * @notice Verifies each repayment is separated by 30 days.
     */
    function test_GetRepaymentSchedule_DatesIncreaseBy30Days() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (uint256[] memory dueDates,) = loanEngine.getRepaymentSchedule(1);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        for (uint256 i = 0; i < dueDates.length; ++i) {
            assertEq(dueDates[i], loan.startDate + ((i + 1) * PAYMENT_INTERVAL));
        }
    }

    /**
     * @notice Verifies scheduled installments match monthlyPayment.
     */
    function test_GetRepaymentSchedule_ReturnsMonthlyPayments() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        (, uint256[] memory payments) = loanEngine.getRepaymentSchedule(1);

        for (uint256 i = 0; i < payments.length - 1; ++i) {
            assertEq(payments[i], MONTHLY_PAYMENT);
        }
    }

    /**
     * @notice Verifies the final scheduled payment accounts for
     *         rounding.
     */
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

    /**
     * @notice Verifies nonexistent loans cannot return a repayment
     *         schedule.
     */
    function test_RevertWhen_ScheduleLoanDoesNotExist() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.getRepaymentSchedule(999);
    }

    /*//////////////////////////////////////////////////////////////
                        DEFAULT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies a loan cannot be defaulted during the grace period.
     */
    function test_RevertWhen_DefaultCalledDuringGracePeriod() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        vm.warp(loan.nextDueDate + DEFAULT_GRACE_PERIOD);

        vm.expectRevert(ILoanEngine.PaymentNotDue.selector);

        loanEngine.markDefaulted(1);
    }

    /**
     * @notice Verifies an overdue loan can be defaulted after
     *         the grace period.
     */
    function test_MarkDefaulted_AfterGracePeriod() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        ILoanEngine.Loan memory loan = loanEngine.getLoan(1);

        vm.warp(loan.nextDueDate + DEFAULT_GRACE_PERIOD + 1);

        loanEngine.markDefaulted(1);

        loan = loanEngine.getLoan(1);

        assertEq(uint256(loan.status), uint256(ILoanEngine.LoanStatus.Defaulted));
    }

    /**
     * @notice Verifies defaulting a nonexistent loan reverts.
     */
    function test_RevertWhen_DefaultingNonexistentLoan() public {
        vm.expectRevert(ILoanEngine.LoanNotFound.selector);

        loanEngine.markDefaulted(999);
    }

    /**
     * @notice Verifies an active loan cannot be defaulted before
     *         its grace period.
     */
    function test_RevertWhen_DefaultingBeforeDueDate() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        vm.expectRevert(ILoanEngine.PaymentNotDue.selector);

        loanEngine.markDefaulted(1);
    }

    /**
     * @notice Verifies a repaid loan cannot be defaulted.
     */
    function test_RevertWhen_DefaultingRepaidLoan() public {
        _prepareRepayment();

        vm.startPrank(borrower);

        loanEngine.repayLoan(1, MONTHLY_PAYMENT);

        uint256 remaining = loanEngine.getRemainingBalance(1);

        stableCoin.approve(address(loanEngine), remaining);

        loanEngine.repayLoan(1, remaining);

        vm.stopPrank();

        vm.warp(block.timestamp + DEFAULT_GRACE_PERIOD + PAYMENT_INTERVAL + 1);

        vm.expectRevert(ILoanEngine.LoanNotActive.selector);

        loanEngine.markDefaulted(1);
    }

    /**
     * @notice Verifies defaulting a loan emits LoanDefaulted.
     */
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

    /**
     * @notice Verifies loan IDs increment sequentially.
     */
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

    /**
     * @notice Verifies outstanding debt accumulates across borrowers.
     */
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

    /**
     * @notice Verifies one borrower's repayment does not affect
     *         another borrower's loan state.
     */
    function test_Repayment_OnlyUpdatesBorrowersLoan() public {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        _mockActiveMember(borrowerTwo);
        _mockSavings(borrowerTwo, SAVINGS_BALANCE);
        _mockRiskTier(borrowerTwo, ICreditScore.RiskTier.VeryLow);

        vm.prank(borrowerTwo);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        stableCoin.mint(borrower, MONTHLY_PAYMENT);

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

    /**
     * @notice Fuzzes valid loan amounts within the 3x savings limit.
     */
    function testFuzz_ValidLoanAmount(uint256 principal) public {
        principal = bound(principal, 1 ether, SAVINGS_BALANCE * 3);

        _mockLoanTerms(principal, VERY_LOW_RATE_BPS, DURATION, MONTHLY_PAYMENT, TOTAL_REPAYMENT);

        vm.prank(borrower);

        loanEngine.applyForLoan(principal, DURATION);

        assertEq(loanEngine.getLoan(1).principal, principal);
    }

    /**
     * @notice Fuzzes loan amounts above the 3x savings limit.
     */
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
     * @notice Prepares a borrower and loan for repayment tests.
     */
    function _prepareRepayment() internal {
        vm.prank(borrower);

        loanEngine.applyForLoan(PRINCIPAL, DURATION);

        stableCoin.mint(borrower, TOTAL_REPAYMENT);

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
     * @notice Mocks the actuarial engine's monthly-payment calculation.
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
