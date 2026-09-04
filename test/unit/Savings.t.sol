// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {Savings} from "../../src/Savings.sol";
import {ISavings} from "../../src/interfaces/ISavings.sol";
import {CoopVault} from "../../src/CoopVault.sol";
import {ICoopVault} from "../../src/interfaces/ICoopVault.sol";

contract SavingsTest is Test {
    /*//////////////////////////////////////////////////////////////
    STATE
    //////////////////////////////////////////////////////////////*/

    Savings internal savings;
    CoopVault internal coopVault;
    ERC20Mock internal stablecoin;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie");
    address internal nonMember = makeAddr("nonMember");

    bytes32 internal aliceNationalId = keccak256("alice-national-id");

    bytes32 internal bobNationalId = keccak256("bob-national-id");

    bytes32 internal charlieNationalId = keccak256("charlie-national-id");

    uint256 internal constant INITIAL_BALANCE = 1_000_000e18;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount, uint256 newBalance);

    event Withdraw(address indexed user, uint256 amount, uint256 newBalance);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        stablecoin = new ERC20Mock();

        vm.prank(owner);
        coopVault = new CoopVault();

        savings = new Savings(address(stablecoin), address(coopVault));

        stablecoin.mint(alice, INITIAL_BALANCE);
        stablecoin.mint(bob, INITIAL_BALANCE);
        stablecoin.mint(charlie, INITIAL_BALANCE);

        vm.prank(alice);
        coopVault.registerMember(aliceNationalId);

        vm.prank(bob);
        coopVault.registerMember(bobNationalId);

        vm.prank(charlie);
        coopVault.registerMember(charlieNationalId);

        vm.prank(alice);
        stablecoin.approve(address(savings), type(uint256).max);

        vm.prank(bob);
        stablecoin.approve(address(savings), type(uint256).max);

        vm.prank(charlie);
        stablecoin.approve(address(savings), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertConstructor_InvalidStablecoin() public {
        vm.expectRevert(ISavings.InvalidAddress.selector);

        new Savings(address(0), address(coopVault));
    }

    function test_RevertConstructor_InvalidCoopVault() public {
        vm.expectRevert(ISavings.InvalidAddress.selector);

        new Savings(address(stablecoin), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        INITIAL STATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(savings.totalSavings(), 0);

        assertEq(savings.balanceOf(alice), 0);

        assertEq(savings.balanceOf(bob), 0);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.balance, 0);
        assertEq(account.totalDeposited, 0);
        assertEq(account.totalWithdrawn, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit() public {
        uint256 amount = 100e18;

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        vm.prank(alice);
        savings.deposit(amount);

        assertEq(savings.balanceOf(alice), amount);

        assertEq(savings.totalSavings(), amount);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore - amount);

        assertEq(stablecoin.balanceOf(address(savings)), amount);
    }

    function test_Deposit_UpdatesSavingsAccount() public {
        uint256 amount = 250e18;

        vm.prank(alice);
        savings.deposit(amount);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.balance, amount);
        assertEq(account.totalDeposited, amount);
        assertEq(account.totalWithdrawn, 0);
    }

    function test_Deposit_EmitsEvent() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, false, false, true);

        emit Deposit(alice, amount, amount);

        vm.prank(alice);
        savings.deposit(amount);
    }

    function test_Deposit_MultipleTimes() public {
        uint256 firstDeposit = 100e18;
        uint256 secondDeposit = 250e18;

        vm.startPrank(alice);

        savings.deposit(firstDeposit);
        savings.deposit(secondDeposit);

        vm.stopPrank();

        assertEq(savings.balanceOf(alice), firstDeposit + secondDeposit);

        assertEq(savings.totalSavings(), firstDeposit + secondDeposit);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.balance, firstDeposit + secondDeposit);

        assertEq(account.totalDeposited, firstDeposit + secondDeposit);

        assertEq(account.totalWithdrawn, 0);
    }

    function test_Deposit_DifferentMembers() public {
        uint256 aliceAmount = 100e18;
        uint256 bobAmount = 250e18;

        vm.prank(alice);
        savings.deposit(aliceAmount);

        vm.prank(bob);
        savings.deposit(bobAmount);

        assertEq(savings.balanceOf(alice), aliceAmount);

        assertEq(savings.balanceOf(bob), bobAmount);

        assertEq(savings.totalSavings(), aliceAmount + bobAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertDeposit_ZeroAmount() public {
        vm.expectRevert(ISavings.CannotBeZero.selector);

        vm.prank(alice);
        savings.deposit(0);
    }

    function test_RevertDeposit_NonMember() public {
        uint256 amount = 100e18;

        stablecoin.mint(nonMember, amount);

        vm.prank(nonMember);
        stablecoin.approve(address(savings), type(uint256).max);

        vm.expectRevert(ISavings.NotMember.selector);

        vm.prank(nonMember);
        savings.deposit(amount);
    }

    function test_RevertDeposit_InactiveMember() public {
        uint256 amount = 100e18;

        vm.prank(owner);
        coopVault.deactivateMember(alice);

        assertTrue(coopVault.isMember(alice));

        assertFalse(coopVault.isActiveMember(alice));

        vm.expectRevert(ISavings.NotMember.selector);

        vm.prank(alice);
        savings.deposit(amount);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Withdraw() public {
        uint256 depositAmount = 500e18;
        uint256 withdrawAmount = 200e18;

        vm.prank(alice);
        savings.deposit(depositAmount);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        vm.prank(alice);
        savings.withdraw(withdrawAmount);

        assertEq(savings.balanceOf(alice), depositAmount - withdrawAmount);

        assertEq(savings.totalSavings(), depositAmount - withdrawAmount);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + withdrawAmount);

        assertEq(stablecoin.balanceOf(address(savings)), depositAmount - withdrawAmount);
    }

    function test_Withdraw_UpdatesSavingsAccount() public {
        uint256 depositAmount = 500e18;
        uint256 withdrawAmount = 200e18;

        vm.prank(alice);
        savings.deposit(depositAmount);

        vm.prank(alice);
        savings.withdraw(withdrawAmount);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.balance, depositAmount - withdrawAmount);

        assertEq(account.totalDeposited, depositAmount);

        assertEq(account.totalWithdrawn, withdrawAmount);
    }

    function test_Withdraw_EmitsEvent() public {
        uint256 depositAmount = 500e18;
        uint256 withdrawAmount = 200e18;
        uint256 expectedBalance = depositAmount - withdrawAmount;

        vm.prank(alice);
        savings.deposit(depositAmount);

        vm.expectEmit(true, false, false, true);

        emit Withdraw(alice, withdrawAmount, expectedBalance);

        vm.prank(alice);
        savings.withdraw(withdrawAmount);
    }

    function test_Withdraw_EntireBalance() public {
        uint256 amount = 500e18;

        vm.prank(alice);
        savings.deposit(amount);

        vm.prank(alice);
        savings.withdraw(amount);

        assertEq(savings.balanceOf(alice), 0);

        assertEq(savings.totalSavings(), 0);

        assertEq(stablecoin.balanceOf(address(savings)), 0);
    }

    function test_Withdraw_MultipleTimes() public {
        uint256 depositAmount = 1_000e18;

        vm.prank(alice);
        savings.deposit(depositAmount);

        vm.prank(alice);
        savings.withdraw(200e18);

        vm.prank(alice);
        savings.withdraw(300e18);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.balance, 500e18);

        assertEq(account.totalDeposited, 1_000e18);

        assertEq(account.totalWithdrawn, 500e18);

        assertEq(savings.totalSavings(), 500e18);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWithdraw_ZeroAmount() public {
        vm.expectRevert(ISavings.CannotBeZero.selector);

        vm.prank(alice);
        savings.withdraw(0);
    }

    function test_RevertWithdraw_NonMember() public {
        vm.expectRevert(ISavings.NotMember.selector);

        vm.prank(nonMember);
        savings.withdraw(1e18);
    }

    function test_RevertWithdraw_InsufficientBalance() public {
        vm.prank(alice);
        savings.deposit(100e18);

        vm.expectRevert(ISavings.InsufficientBalance.selector);

        vm.prank(alice);
        savings.withdraw(101e18);
    }

    function test_RevertWithdraw_EntirelyEmptyAccount() public {
        vm.expectRevert(ISavings.InsufficientBalance.selector);

        vm.prank(alice);
        savings.withdraw(1e18);
    }

    function test_Withdraw_AllowedForInactiveMember() public {
        uint256 amount = 500e18;

        vm.prank(alice);
        savings.deposit(amount);

        vm.prank(owner);
        coopVault.deactivateMember(alice);

        assertFalse(coopVault.isActiveMember(alice));

        assertTrue(coopVault.isMember(alice));

        vm.prank(alice);
        savings.withdraw(amount);

        assertEq(savings.balanceOf(alice), 0);

        assertEq(savings.totalSavings(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    ACCOUNTING INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TotalSavingsEqualsSumOfBalances() public {
        vm.prank(alice);
        savings.deposit(100e18);

        vm.prank(bob);
        savings.deposit(250e18);

        vm.prank(charlie);
        savings.deposit(400e18);

        uint256 expectedTotal = savings.balanceOf(alice) + savings.balanceOf(bob) + savings.balanceOf(charlie);

        assertEq(savings.totalSavings(), expectedTotal);
    }

    function test_TotalSavingsAfterWithdrawals() public {
        vm.prank(alice);
        savings.deposit(500e18);

        vm.prank(bob);
        savings.deposit(300e18);

        vm.prank(alice);
        savings.withdraw(200e18);

        vm.prank(bob);
        savings.withdraw(100e18);

        uint256 expectedTotal = savings.balanceOf(alice) + savings.balanceOf(bob);

        assertEq(savings.totalSavings(), expectedTotal);

        assertEq(savings.totalSavings(), 500e18);
    }

    function test_DepositThenWithdraw_PreservesHistory() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(alice);
        savings.withdraw(400e18);

        vm.prank(alice);
        savings.deposit(200e18);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.balance, 800e18);

        assertEq(account.totalDeposited, 1_200e18);

        assertEq(account.totalWithdrawn, 400e18);
    }

    /*//////////////////////////////////////////////////////////////
                        MEMBER ISOLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MembersHaveIndependentAccounts() public {
        vm.prank(alice);
        savings.deposit(100e18);

        vm.prank(bob);
        savings.deposit(500e18);

        vm.prank(alice);
        savings.withdraw(50e18);

        assertEq(savings.balanceOf(alice), 50e18);

        assertEq(savings.balanceOf(bob), 500e18);

        assertEq(savings.totalSavings(), 550e18);
    }

    function test_WithdrawDoesNotAffectOtherMember() public {
        vm.prank(alice);
        savings.deposit(300e18);

        vm.prank(bob);
        savings.deposit(700e18);

        vm.prank(alice);
        savings.withdraw(100e18);

        assertEq(savings.balanceOf(alice), 200e18);

        assertEq(savings.balanceOf(bob), 700e18);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_BALANCE);

        uint256 balanceBefore = stablecoin.balanceOf(alice);

        vm.prank(alice);
        savings.deposit(amount);

        assertEq(savings.balanceOf(alice), amount);

        assertEq(savings.totalSavings(), amount);

        assertEq(stablecoin.balanceOf(alice), balanceBefore - amount);

        assertEq(stablecoin.balanceOf(address(savings)), amount);
    }

    function testFuzz_Withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);

        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        vm.prank(alice);
        savings.deposit(depositAmount);

        vm.prank(alice);
        savings.withdraw(withdrawAmount);

        assertEq(savings.balanceOf(alice), depositAmount - withdrawAmount);

        assertEq(savings.totalSavings(), depositAmount - withdrawAmount);

        ISavings.SavingsAccount memory account = savings.getSavingsAccount(alice);

        assertEq(account.totalDeposited, depositAmount);

        assertEq(account.totalWithdrawn, withdrawAmount);
    }

    function testFuzz_DepositAndWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);

        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        vm.prank(alice);
        savings.deposit(depositAmount);

        vm.prank(alice);
        savings.withdraw(withdrawAmount);

        uint256 expectedBalance = depositAmount - withdrawAmount;

        assertEq(savings.balanceOf(alice), expectedBalance);

        assertEq(savings.totalSavings(), expectedBalance);
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function test_TokenAccountingMatchesSavings() public {
        vm.prank(alice);
        savings.deposit(100e18);

        vm.prank(bob);
        savings.deposit(250e18);

        vm.prank(alice);
        savings.withdraw(50e18);

        uint256 contractBalance = stablecoin.balanceOf(address(savings));

        assertEq(contractBalance, savings.totalSavings());
    }
}
