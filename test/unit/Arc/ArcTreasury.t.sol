// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ArcTreasury} from "../../../src/sponsors/Arc/ArcTreasury.sol";
import {IArcTreasury} from "../../../src/sponsors/Arc/interfaces/IArcTreasury.sol";

/**
 * @title ArcTreasuryTest
 * @author Maxwell Wire
 * @notice Unit tests for the CoopChain ArcTreasury contract.
 *
 * @dev
 * The treasury uses a hardcoded USDC address for Arc Testnet.
 * Since unit tests run locally, an ERC20Mock is placed at that
 * address using `vm.etch()` so the tests can simulate Arc USDC.
 */
contract ArcTreasuryTest is Test {
    /*//////////////////////////////////////////////////////////////
                            CONTRACTS
    //////////////////////////////////////////////////////////////*/

    ArcTreasury internal treasury;
    ERC20Mock internal usdc;

    /*//////////////////////////////////////////////////////////////
                              ACTORS
    //////////////////////////////////////////////////////////////*/

    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant FUND_AMOUNT = 1_000e6;
    uint256 internal constant RELEASE_AMOUNT = 400e6;
    uint256 internal constant WITHDRAW_AMOUNT = 300e6;

    address internal constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the treasury and configures a mock USDC token
     *         at the Arc Testnet USDC address.
     */
    function setUp() public {
        // Deploy the mock USDC implementation.
        usdc = new ERC20Mock();

        // Place the mock token's runtime bytecode at the Arc
        // Testnet USDC address used by ArcTreasury.
        vm.etch(ARC_TESTNET_USDC, address(usdc).code);

        // The treasury constructor reads the hardcoded Arc USDC
        // address and stores it as the USDC token.
        vm.prank(admin);
        treasury = new ArcTreasury();

        // Fund Alice with mock USDC.
        ERC20Mock(ARC_TESTNET_USDC).mint(alice, 10_000e6);

        // Fund Bob with mock USDC.
        ERC20Mock(ARC_TESTNET_USDC).mint(bob, 10_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the deployer becomes the administrator.
     */
    function test_ConstructorSetsAdmin() public view {
        assertEq(treasury.getAdmin(), admin);
    }

    /**
     * @notice Verifies that the treasury uses the Arc Testnet
     *         USDC contract.
     */
    function test_ConstructorSetsUSDC() public view {
        assertEq(treasury.getUSDC(), ARC_TESTNET_USDC);
    }

    /**
     * @notice Verifies that a newly deployed treasury has zero USDC.
     */
    function test_InitialBalanceIsZero() public view {
        assertEq(treasury.getBalance(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FUND TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that any address can fund the treasury.
     */
    function test_AnyoneCanFundTreasury() public {
        vm.startPrank(alice);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), FUND_AMOUNT);

        treasury.fund(FUND_AMOUNT);

        vm.stopPrank();

        assertEq(treasury.getBalance(), FUND_AMOUNT);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice), 10_000e6 - FUND_AMOUNT);
    }

    /**
     * @notice Verifies that funding emits TreasuryFunded.
     */
    function test_FundEmitsTreasuryFunded() public {
        vm.startPrank(alice);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), FUND_AMOUNT);

        vm.expectEmit(true, true, false, true);

        emit IArcTreasury.TreasuryFunded(alice, FUND_AMOUNT);

        treasury.fund(FUND_AMOUNT);

        vm.stopPrank();
    }

    /**
     * @notice Verifies that zero-value funding is rejected.
     */
    function test_RevertWhenFundingZeroAmount() public {
        vm.prank(alice);

        vm.expectRevert(IArcTreasury.InvalidAmount.selector);

        treasury.fund(0);
    }

    /**
     * @notice Verifies that multiple users can fund the treasury.
     */
    function test_MultipleUsersCanFundTreasury() public {
        vm.startPrank(alice);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), FUND_AMOUNT);

        treasury.fund(FUND_AMOUNT);

        vm.stopPrank();

        vm.startPrank(bob);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), FUND_AMOUNT);

        treasury.fund(FUND_AMOUNT);

        vm.stopPrank();

        assertEq(treasury.getBalance(), FUND_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                           RELEASE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the administrator can release USDC.
     */
    function test_AdminCanReleaseFunds() public {
        _fundTreasury(FUND_AMOUNT);

        uint256 aliceBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice);

        vm.prank(admin);

        treasury.release(alice, RELEASE_AMOUNT);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice), aliceBalanceBefore + RELEASE_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT - RELEASE_AMOUNT);
    }

    /**
     * @notice Verifies that release emits TreasuryReleased.
     */
    function test_ReleaseEmitsTreasuryReleased() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectEmit(true, true, false, true);

        emit IArcTreasury.TreasuryReleased(alice, RELEASE_AMOUNT);

        treasury.release(alice, RELEASE_AMOUNT);
    }

    /**
     * @notice Verifies that non-authorized addresses cannot release funds.
     */
    function test_RevertWhenUnauthorizedRelease() public {
        _fundTreasury(FUND_AMOUNT);

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(alice);

        treasury.release(bob, RELEASE_AMOUNT);
    }

    /**
     * @notice Verifies that release rejects the zero address.
     */
    function test_RevertWhenReleaseRecipientIsZeroAddress() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectRevert(IArcTreasury.InvalidAddress.selector);

        treasury.release(address(0), RELEASE_AMOUNT);
    }

    /**
     * @notice Verifies that release rejects zero amounts.
     */
    function test_RevertWhenReleaseAmountIsZero() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectRevert(IArcTreasury.InvalidAmount.selector);

        treasury.release(alice, 0);
    }

    /**
     * @notice Verifies that release cannot exceed treasury balance.
     */
    function test_RevertWhenReleaseExceedsBalance() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectRevert(IArcTreasury.InsufficientBalance.selector);

        treasury.release(alice, FUND_AMOUNT + 1);
    }

    /*//////////////////////////////////////////////////////////////
                       OPERATOR TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the administrator can authorize an operator.
     */
    function test_AdminCanAuthorizeOperator() public {
        vm.prank(admin);

        treasury.setOperatorAuthorization(alice, true);

        assertTrue(treasury.isOperatorAuthorized(alice));
    }

    /**
     * @notice Verifies that the administrator can revoke an operator.
     */
    function test_AdminCanRevokeOperator() public {
        vm.startPrank(admin);

        treasury.setOperatorAuthorization(alice, true);

        treasury.setOperatorAuthorization(alice, false);

        vm.stopPrank();

        assertFalse(treasury.isOperatorAuthorized(alice));
    }

    /**
     * @notice Verifies that setting operator authorization emits
     *         OperatorAuthorizationUpdated.
     */
    function test_SetOperatorAuthorizationEmitsEvent() public {
        vm.expectEmit(true, false, false, true);

        emit IArcTreasury.OperatorAuthorizationUpdated(alice, true);

        vm.prank(admin);

        treasury.setOperatorAuthorization(alice, true);
    }

    /**
     * @notice Verifies that an authorized operator can release USDC.
     */
    function test_OperatorCanReleaseFunds() public {
        uint256 treasuryAmount = 10e6;
        uint256 releaseAmount = 4e6;

        _fundTreasury(treasuryAmount);

        vm.prank(admin);

        treasury.setOperatorAuthorization(alice, true);

        uint256 aliceBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice);

        vm.prank(alice);

        treasury.release(alice, releaseAmount);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice), aliceBalanceBefore + releaseAmount);

        assertEq(treasury.getBalance(), treasuryAmount - releaseAmount);
    }

    /**
     * @notice Verifies that an unauthorized address cannot release USDC.
     */
    function test_RevertWhenUnauthorizedOperatorReleases() public {
        _fundTreasury(10e6);

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(alice);

        treasury.release(alice, 1e6);
    }

    /**
     * @notice Verifies that a revoked operator can no longer release USDC.
     */
    function test_RevertWhenRevokedOperatorReleases() public {
        _fundTreasury(10e6);

        vm.startPrank(admin);

        treasury.setOperatorAuthorization(alice, true);

        treasury.setOperatorAuthorization(alice, false);

        vm.stopPrank();

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(alice);

        treasury.release(alice, 1e6);
    }

    /**
     * @notice Verifies that an authorized operator cannot withdraw
     *         treasury funds.
     */
    function test_RevertWhenOperatorWithdraws() public {
        _fundTreasury(10e6);

        vm.prank(admin);

        treasury.setOperatorAuthorization(alice, true);

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(alice);

        treasury.withdraw(alice, 1e6);
    }

    /**
     * @notice Verifies that a zero address cannot be authorized
     *         as an operator.
     */
    function test_RevertWhenAuthorizingZeroAddress() public {
        vm.expectRevert(IArcTreasury.InvalidAddress.selector);

        vm.prank(admin);

        treasury.setOperatorAuthorization(address(0), true);
    }

    /**
     * @notice Verifies that a non-admin cannot authorize an operator.
     */
    function test_RevertWhenNonAdminAuthorizesOperator() public {
        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(alice);

        treasury.setOperatorAuthorization(bob, true);
    }

    /**
     * @notice Verifies that an operator remains unable to withdraw
     *         even after being authorized for release operations.
     */
    function test_OperatorAuthorizationDoesNotGrantWithdrawPermission() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        treasury.setOperatorAuthorization(alice, true);

        assertTrue(treasury.isOperatorAuthorized(alice));

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        vm.prank(alice);

        treasury.withdraw(alice, WITHDRAW_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that the administrator can withdraw USDC.
     */
    function test_AdminCanWithdraw() public {
        _fundTreasury(FUND_AMOUNT);

        uint256 adminBalanceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(admin);

        vm.prank(admin);

        treasury.withdraw(admin, WITHDRAW_AMOUNT);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(admin), adminBalanceBefore + WITHDRAW_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT - WITHDRAW_AMOUNT);
    }

    /**
     * @notice Verifies that withdrawal emits TreasuryWithdrawn.
     */
    function test_WithdrawEmitsTreasuryWithdrawn() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectEmit(true, true, false, true);

        emit IArcTreasury.TreasuryWithdrawn(bob, WITHDRAW_AMOUNT);

        treasury.withdraw(bob, WITHDRAW_AMOUNT);
    }

    /**
     * @notice Verifies that non-admin addresses cannot withdraw funds.
     */
    function test_RevertWhenUnauthorizedWithdraw() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(alice);

        vm.expectRevert(IArcTreasury.Unauthorized.selector);

        treasury.withdraw(bob, WITHDRAW_AMOUNT);
    }

    /**
     * @notice Verifies that withdrawal rejects the zero address.
     */
    function test_RevertWhenWithdrawRecipientIsZeroAddress() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectRevert(IArcTreasury.InvalidAddress.selector);

        treasury.withdraw(address(0), WITHDRAW_AMOUNT);
    }

    /**
     * @notice Verifies that withdrawal rejects zero amounts.
     */
    function test_RevertWhenWithdrawAmountIsZero() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectRevert(IArcTreasury.InvalidAmount.selector);

        treasury.withdraw(alice, 0);
    }

    /**
     * @notice Verifies that withdrawal cannot exceed treasury balance.
     */
    function test_RevertWhenWithdrawExceedsBalance() public {
        _fundTreasury(FUND_AMOUNT);

        vm.prank(admin);

        vm.expectRevert(IArcTreasury.InsufficientBalance.selector);

        treasury.withdraw(alice, FUND_AMOUNT + 1);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that getBalance returns the actual USDC
     *         balance held by the treasury.
     */
    function test_GetBalanceReturnsTreasuryUSDCBalance() public {
        _fundTreasury(FUND_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(address(treasury)), FUND_AMOUNT);
    }

    /**
     * @notice Verifies that getUSDC returns the configured token.
     */
    function test_GetUSDCReturnsArcTestnetUSDC() public view {
        assertEq(treasury.getUSDC(), ARC_TESTNET_USDC);
    }

    /**
     * @notice Verifies that getAdmin returns the deployer.
     */
    function test_GetAdminReturnsAdmin() public view {
        assertEq(treasury.getAdmin(), admin);
    }

    /**
     * @notice Verifies that an address is not an authorized operator
     *         by default.
     */
    function test_IsOperatorAuthorizedReturnsFalseByDefault() public view {
        assertFalse(treasury.isOperatorAuthorized(alice));
    }

    /*//////////////////////////////////////////////////////////////
                         FULL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies the complete treasury lifecycle:
     *         fund, release, and withdraw.
     */
    function test_FullTreasuryLifecycle() public {
        // Alice funds the treasury.
        vm.startPrank(alice);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), FUND_AMOUNT);

        treasury.fund(FUND_AMOUNT);

        vm.stopPrank();

        assertEq(treasury.getBalance(), FUND_AMOUNT);

        // Admin releases part of the treasury to Bob.
        vm.prank(admin);

        treasury.release(bob, RELEASE_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT - RELEASE_AMOUNT);

        // Admin withdraws another portion.
        vm.prank(admin);

        treasury.withdraw(alice, WITHDRAW_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT - RELEASE_AMOUNT - WITHDRAW_AMOUNT);
    }

    /**
     * @notice Verifies that release and withdraw are independent
     *         operations with the same underlying USDC movement.
     */
    function test_ReleaseAndWithdrawBothTransferUSDC() public {
        _fundTreasury(FUND_AMOUNT);

        uint256 bobBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(bob);

        uint256 aliceBefore = ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice);

        vm.startPrank(admin);

        treasury.release(bob, RELEASE_AMOUNT);

        treasury.withdraw(alice, WITHDRAW_AMOUNT);

        vm.stopPrank();

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(bob), bobBefore + RELEASE_AMOUNT);

        assertEq(ERC20Mock(ARC_TESTNET_USDC).balanceOf(alice), aliceBefore + WITHDRAW_AMOUNT);

        assertEq(treasury.getBalance(), FUND_AMOUNT - RELEASE_AMOUNT - WITHDRAW_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that funding increases the treasury balance
     *         by exactly the deposited amount.
     * @param amount Amount of USDC to deposit.
     */
    function testFuzz_FundingIncreasesBalance(uint256 amount) public {
        amount = bound(amount, 1, 10_000e6);

        ERC20Mock(ARC_TESTNET_USDC).mint(alice, amount);

        vm.startPrank(alice);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), amount);

        treasury.fund(amount);

        vm.stopPrank();

        assertEq(treasury.getBalance(), amount);
    }

    /**
     * @notice Verifies that a valid release never leaves the treasury
     *         with a negative balance.
     * @param amount Amount to release.
     */
    function testFuzz_ReleaseNeverExceedsBalance(uint256 amount) public {
        amount = bound(amount, 1, FUND_AMOUNT);

        _fundTreasury(FUND_AMOUNT);

        uint256 balanceBefore = treasury.getBalance();

        vm.prank(admin);

        treasury.release(alice, amount);

        assertEq(treasury.getBalance(), balanceBefore - amount);
    }

    /**
     * @notice Verifies that a valid withdrawal never leaves the
     *         treasury with a negative balance.
     * @param amount Amount to withdraw.
     */
    function testFuzz_WithdrawNeverExceedsBalance(uint256 amount) public {
        amount = bound(amount, 1, FUND_AMOUNT);

        _fundTreasury(FUND_AMOUNT);

        uint256 balanceBefore = treasury.getBalance();

        vm.prank(admin);

        treasury.withdraw(alice, amount);

        assertEq(treasury.getBalance(), balanceBefore - amount);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Funds the treasury with mock Arc USDC.
     * @param amount Amount of USDC to deposit.
     */
    function _fundTreasury(uint256 amount) internal {
        vm.startPrank(alice);

        ERC20Mock(ARC_TESTNET_USDC).approve(address(treasury), amount);

        treasury.fund(amount);

        vm.stopPrank();
    }
}
