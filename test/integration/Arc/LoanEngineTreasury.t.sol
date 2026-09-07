// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ArcTreasury} from "../../../src/sponsors/Arc/ArcTreasury.sol";
import {IArcTreasury} from "../../../src/sponsors/Arc/interfaces/IArcTreasury.sol";

/**
 * @title LoanEngineTreasuryTest
 * @author Maxwell Wire
 * @notice Integration tests for the simulated LoanEngine and ArcTreasury.
 *
 * @dev
 * This test suite verifies the intended CoopChain settlement architecture
 * before integrating the real LoanEngine contract.
 *
 * The simulated LoanEngine is represented by an address that is authorized
 * by the ArcTreasury administrator.
 *
 * The integration flow is:
 *
 *     CoopChain LoanEngine
 *             │
 *             │ authorized operator
 *             ▼
 *        ArcTreasury
 *             │
 *             │ USDC
 *             ▼
 *          Borrower
 *
 * The tests verify that:
 * - the treasury can authorize the LoanEngine address;
 * - the authorized LoanEngine can release USDC to a borrower;
 * - treasury balances decrease correctly after disbursement;
 * - unauthorized addresses cannot release USDC;
 * - revoked operators cannot release USDC;
 * - LoanEngine cannot withdraw treasury funds.
 *
 * The real LoanEngine contract is intentionally not imported or deployed.
 * This isolates the treasury authorization boundary from LoanEngine's
 * internal lending logic.
 */
contract LoanEngineTreasuryTest is Test {
    /*//////////////////////////////////////////////////////////////
                            CONTRACTS
    //////////////////////////////////////////////////////////////*/

    ArcTreasury internal treasury;
    ERC20Mock internal usdc;

    /*//////////////////////////////////////////////////////////////
                              ACTORS
    //////////////////////////////////////////////////////////////*/

    address internal admin = makeAddr("admin");
    address internal loanEngine = makeAddr("loanEngine");
    address internal borrower = makeAddr("borrower");
    address internal randomUser = makeAddr("randomUser");

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    uint256 internal constant TREASURY_FUNDING = 1_000e6;
    uint256 internal constant LOAN_AMOUNT = 400e6;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the treasury and configures mock Arc Testnet USDC.
     *
     * @dev
     * The mock token runtime bytecode is placed at the real Arc Testnet
     * USDC address so that ArcTreasury interacts with a local ERC-20
     * implementation during testing.
     */
    function setUp() public {
        // Deploy mock USDC implementation.
        usdc = new ERC20Mock();

        // Place the mock implementation at the Arc Testnet USDC address.
        vm.etch(ARC_TESTNET_USDC, address(usdc).code);

        // Deploy ArcTreasury with admin as the deployer.
        vm.prank(admin);
        treasury = new ArcTreasury();

        // Give a funding account enough mock USDC to fund the treasury.
        ERC20Mock(ARC_TESTNET_USDC).mint(admin, TREASURY_FUNDING);
    }

    /*//////////////////////////////////////////////////////////////
                         DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the treasury is deployed with the expected
     *         administrator.
     */
    function test_DeployTreasuryWithAdmin() public view {
        assertEq(treasury.getAdmin(), admin);
    }

    /**
     * @notice Verifies that the treasury uses the Arc Testnet USDC token.
     */
    function test_TreasuryUsesArcTestnetUSDC() public view {
        assertEq(treasury.getUSDC(), ARC_TESTNET_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                      OPERATOR AUTHORIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the administrator can authorize the simulated
     *         LoanEngine as a treasury operator.
     */
    function test_AdminCanAuthorizeLoanEngine() public {
        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        assertTrue(treasury.isOperatorAuthorized(loanEngine));
    }

    /**
     * @notice Verifies that the LoanEngine is not authorized by default.
     */
    function test_LoanEngineIsUnauthorizedByDefault() public view {
        assertFalse(treasury.isOperatorAuthorized(loanEngine));
    }

    /*//////////////////////////////////////////////////////////////
                         FUNDING TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the treasury can be funded before loan
     *         disbursement.
     */
    function test_FundTreasuryBeforeLoanDisbursement() public {
        _fundTreasury(TREASURY_FUNDING);

        assertEq(treasury.getBalance(), TREASURY_FUNDING);
    }

    /*//////////////////////////////////////////////////////////////
                    LOAN DISBURSEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies the core integration flow:
     *
     *         1. Fund treasury.
     *         2. Authorize LoanEngine.
     *         3. LoanEngine releases USDC.
     *         4. Borrower receives the loan.
     */
    function test_LoanEngineCanDisburseLoan() public {
        _fundTreasury(TREASURY_FUNDING);

        // Authorize the simulated LoanEngine.
        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        uint256 borrowerBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower);

        // Simulate LoanEngine requesting the loan disbursement.
        vm.prank(loanEngine);

        treasury.release(borrower, LOAN_AMOUNT);

        // Borrower receives the loan amount.
        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower), borrowerBalanceBefore + LOAN_AMOUNT);

        // Treasury retains the remaining funds.
        assertEq(treasury.getBalance(), TREASURY_FUNDING - LOAN_AMOUNT);
    }

    /**
     * @notice Verifies that loan disbursement decreases the treasury
     *         balance by exactly the released amount.
     */
    function test_LoanDisbursementReducesTreasuryBalance() public {
        _fundTreasury(TREASURY_FUNDING);

        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        uint256 balanceBefore = treasury.getBalance();

        vm.prank(loanEngine);

        treasury.release(borrower, LOAN_AMOUNT);

        assertEq(treasury.getBalance(), balanceBefore - LOAN_AMOUNT);
    }

    /**
     * @notice Verifies that the USDC received by the borrower is exactly
     *         the amount requested by the simulated LoanEngine.
     */
    function test_BorrowerReceivesExactLoanAmount() public {
        _fundTreasury(TREASURY_FUNDING);

        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        uint256 borrowerBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower);

        vm.prank(loanEngine);

        treasury.release(borrower, LOAN_AMOUNT);

        uint256 borrowerBalanceAfter = ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower);

        assertEq(borrowerBalanceAfter - borrowerBalanceBefore, LOAN_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                       AUTHORIZATION SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that a random address cannot disburse a loan.
     */
    function test_UnauthorizedAddressCannotDisburseLoan() public {
        _fundTreasury(TREASURY_FUNDING);

        uint256 borrowerBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower);

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(randomUser);

        treasury.release(borrower, LOAN_AMOUNT);

        // No USDC should have been transferred.
        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower), borrowerBalanceBefore);

        // Treasury balance must remain unchanged.
        assertEq(treasury.getBalance(), TREASURY_FUNDING);
    }

    /**
     * @notice Verifies that revoking the LoanEngine removes its ability
     *         to disburse loans.
     */
    function test_RevokedLoanEngineCannotDisburseLoan() public {
        _fundTreasury(TREASURY_FUNDING);

        vm.startPrank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);
        treasury.setOperatorAuthorization(loanEngine, false);

        vm.stopPrank();

        assertFalse(treasury.isOperatorAuthorized(loanEngine));

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(loanEngine);

        treasury.release(borrower, LOAN_AMOUNT);

        assertEq(treasury.getBalance(), TREASURY_FUNDING);
    }

    /**
     * @notice Verifies that an unauthorized address cannot authorize
     *         itself or another address as a LoanEngine operator.
     */
    function test_NonAdminCannotAuthorizeLoanEngine() public {
        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(randomUser);

        treasury.setOperatorAuthorization(loanEngine, true);

        assertFalse(treasury.isOperatorAuthorized(loanEngine));
    }

    /*//////////////////////////////////////////////////////////////
                         WITHDRAWAL SECURITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the LoanEngine cannot withdraw treasury funds
     *         even when authorized as an operator.
     */
    function test_LoanEngineCannotWithdraw() public {
        _fundTreasury(TREASURY_FUNDING);

        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        assertTrue(treasury.isOperatorAuthorized(loanEngine));

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(loanEngine);

        treasury.withdraw(loanEngine, LOAN_AMOUNT);

        // Withdrawal must not alter the treasury balance.
        assertEq(treasury.getBalance(), TREASURY_FUNDING);
    }

    /**
     * @notice Verifies that LoanEngine authorization grants release
     *         permission only and does not grant administrative withdrawal
     *         permission.
     */
    function test_LoanEngineAuthorizationOnlyGrantsReleasePermission() public {
        _fundTreasury(TREASURY_FUNDING);

        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        // Release is permitted.
        vm.prank(loanEngine);

        treasury.release(borrower, LOAN_AMOUNT);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower), LOAN_AMOUNT);

        // Withdrawal remains forbidden.
        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(loanEngine);

        treasury.withdraw(loanEngine, 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                       FULL INTEGRATION FLOW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies the complete simulated LoanEngine settlement flow:
     *
     *         Admin
     *           │
     *           ├── authorizes LoanEngine
     *           │
     *           ▼
     *       ArcTreasury
     *           │
     *           │ funded with USDC
     *           │
     *           ▼
     *      LoanEngine
     *           │
     *           │ release()
     *           ▼
     *       Borrower
     *
     * @dev
     * This test intentionally uses a simulated LoanEngine address.
     * The real LoanEngine contract will be integrated only after this
     * treasury boundary has been proven.
     */
    function test_FullLoanEngineTreasuryLifecycle() public {
        // 1. Fund the treasury.
        _fundTreasury(TREASURY_FUNDING);

        assertEq(treasury.getBalance(), TREASURY_FUNDING);

        // 2. Admin authorizes LoanEngine.
        vm.prank(admin);

        treasury.setOperatorAuthorization(loanEngine, true);

        assertTrue(treasury.isOperatorAuthorized(loanEngine));

        // 3. Record borrower balance before disbursement.
        uint256 borrowerBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower);

        // 4. Simulate LoanEngine requesting the loan disbursement.
        vm.prank(loanEngine);

        treasury.release(borrower, LOAN_AMOUNT);

        // 5. Verify borrower received USDC.
        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(borrower), borrowerBalanceBefore + LOAN_AMOUNT);

        // 6. Verify treasury balance decreased correctly.
        assertEq(treasury.getBalance(), TREASURY_FUNDING - LOAN_AMOUNT);

        // 7. Verify LoanEngine still cannot withdraw.
        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(loanEngine);

        treasury.withdraw(loanEngine, 1e6);

        // Treasury balance remains unchanged after failed withdrawal.
        assertEq(treasury.getBalance(), TREASURY_FUNDING - LOAN_AMOUNT);

        // 8. Verify a random address cannot perform another release.
        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(randomUser);

        treasury.release(borrower, 1e6);

        // Treasury balance remains unchanged after failed release.
        assertEq(treasury.getBalance(), TREASURY_FUNDING - LOAN_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Funds the ArcTreasury with mock USDC.
     * @param amount Amount of USDC to deposit.
     */
    function _fundTreasury(uint256 amount) internal {
        vm.startPrank(admin);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), amount);

        treasury.fund(amount);

        vm.stopPrank();
    }
}
