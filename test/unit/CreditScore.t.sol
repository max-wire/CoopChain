// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {CreditScore} from "../../src/CreditScore.sol";
import {ICreditScore} from "../../src/interfaces/ICreditScore.sol";
import {CoopVault} from "../../src/CoopVault.sol";
import {ICoopVault} from "../../src/interfaces/ICoopVault.sol";
import {Savings} from "../../src/Savings.sol";

contract CreditScoreTest is Test {
    /*//////////////////////////////////////////////////////////////
    STATE
    //////////////////////////////////////////////////////////////*/

    CreditScore internal creditScore;
    CoopVault internal coopVault;
    Savings internal savings;
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

    uint256 internal constant SIX_MONTHS = 180 days;

    uint256 internal constant ONE_YEAR = 365 days;

    uint256 internal constant TWO_YEARS = 730 days;

    uint256 internal constant FIVE_YEARS = 1825 days;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.warp(0);

        stablecoin = new ERC20Mock();

        vm.prank(owner);
        coopVault = new CoopVault();

        savings = new Savings(address(stablecoin), address(coopVault));

        creditScore = new CreditScore(address(coopVault), address(savings));

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

    function test_RevertConstructor_InvalidCoopVault() public {
        vm.expectRevert(CreditScore.InvalidAddress.selector);

        new CreditScore(address(0), address(savings));
    }

    function test_RevertConstructor_InvalidSavings() public {
        vm.expectRevert(CreditScore.InvalidAddress.selector);

        new CreditScore(address(coopVault), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    INITIAL CREDIT SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_NewMember_HasBaseMembershipScore() public view {
        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.membershipScore, 5);

        assertEq(profile.savingsScore, 0);

        assertEq(profile.repaymentScore, 0);

        assertEq(profile.creditScore, 5);

        assertEq(uint256(profile.riskTier), uint256(ICreditScore.RiskTier.VeryHigh));
    }

    function test_NewMember_CalculatedAtTimestamp() public {
        uint256 timestamp = 1_000_000;

        vm.warp(timestamp);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.calculatedAt, timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                    MEMBERSHIP SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MembershipScore_BelowSixMonths() public {
        vm.warp(SIX_MONTHS - 1);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 5);
    }

    function test_MembershipScore_AtSixMonths() public {
        vm.warp(SIX_MONTHS);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 10);
    }

    function test_MembershipScore_BetweenSixMonthsAndOneYear() public {
        vm.warp(SIX_MONTHS + 1 days);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 10);

        vm.warp(ONE_YEAR - 1);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 10);
    }

    function test_MembershipScore_AtOneYear() public {
        vm.warp(ONE_YEAR);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 15);
    }

    function test_MembershipScore_BetweenOneAndTwoYears() public {
        vm.warp(ONE_YEAR + 1 days);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 15);

        vm.warp(TWO_YEARS - 1);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 15);
    }

    function test_MembershipScore_AtTwoYears() public {
        vm.warp(TWO_YEARS);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 25);
    }

    function test_MembershipScore_BetweenTwoAndFiveYears() public {
        vm.warp(TWO_YEARS + 1 days);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 25);

        vm.warp(FIVE_YEARS - 1);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 25);
    }

    function test_MembershipScore_AtFiveYears() public {
        vm.warp(FIVE_YEARS);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 30);
    }

    function test_MembershipScore_AboveFiveYears() public {
        vm.warp(FIVE_YEARS + 365 days);

        assertEq(creditScore.getCreditProfile(alice).membershipScore, 30);
    }

    /*//////////////////////////////////////////////////////////////
                        BALANCE SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SavingsScore_ZeroBalance() public view {
        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.savingsScore, 0);
    }

    function test_SavingsScore_BalanceBelow1000() public {
        vm.prank(alice);
        savings.deposit(999e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        // Balance score = 10
        // Deposit score = 5
        // Discipline = 20
        // Total = 35
        assertEq(profile.savingsScore, 35);
    }

    function test_SavingsScore_BalanceAt1000() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        // Balance = 20
        // Deposit = 5
        // Discipline = 20
        assertEq(profile.savingsScore, 45);
    }

    function test_SavingsScore_BalanceAt5000() public {
        vm.prank(alice);
        savings.deposit(5_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        // Balance = 30
        // Deposit = 10
        // Discipline = 20
        assertEq(profile.savingsScore, 60);
    }

    function test_SavingsScore_BalanceAbove10000() public {
        vm.prank(alice);
        savings.deposit(10_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        // Balance = 30
        // Deposit = 10
        // Discipline = 20
        // Total = 60
        assertEq(profile.savingsScore, 60);
    }
    /*//////////////////////////////////////////////////////////////
                        DEPOSIT SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DepositScore_Below5000() public {
        vm.prank(alice);
        savings.deposit(4_999e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        // Balance = 20
        // Deposit = 5
        // Discipline = 20
        assertEq(profile.savingsScore, 45);
    }

    function test_DepositScore_At5000() public {
        vm.prank(alice);
        savings.deposit(5_000e18);

        // Balance = 30
        // Deposit = 10
        // Discipline = 20
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 60);
    }

    function test_DepositScore_At20000() public {
        vm.prank(alice);
        savings.deposit(20_000e18);

        // Balance = 30
        // Deposit = 15
        // Discipline = 20
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 65);
    }

    function test_DepositScore_At50000() public {
        vm.prank(alice);
        savings.deposit(50_000e18);

        // Balance = 30
        // Deposit = 20
        // Discipline = 20
        // Total = 70
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 70);
    }

    /*//////////////////////////////////////////////////////////////
                    DISCIPLINE SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DisciplineScore_100Percent() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        assertEq(creditScore.getCreditProfile(alice).savingsScore, 45);
    }

    function test_DisciplineScore_90Percent() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(alice);
        savings.withdraw(100e18);

        // Balance = 900
        // Balance score = 10
        // Deposit score = 5
        // Discipline = 20
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 35);
    }

    function test_DisciplineScore_75Percent() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(alice);
        savings.withdraw(250e18);

        // Balance = 750
        // Balance score = 10
        // Deposit score = 5
        // Discipline = 15
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 30);
    }

    function test_DisciplineScore_50Percent() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(alice);
        savings.withdraw(500e18);

        // Balance = 500
        // Balance score = 10
        // Deposit score = 5
        // Discipline = 10
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 25);
    }

    function test_DisciplineScore_25Percent() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(alice);
        savings.withdraw(750e18);

        // Balance = 250
        // Balance score = 10
        // Deposit score = 5
        // Discipline = 5
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 20);
    }

    function test_DisciplineScore_Below25Percent() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(alice);
        savings.withdraw(751e18);

        // Balance = 249
        // Balance score = 10
        // Deposit score = 5
        // Discipline = 0
        assertEq(creditScore.getCreditProfile(alice).savingsScore, 15);
    }

    /*//////////////////////////////////////////////////////////////
                    SAVINGS SCORE CAP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SavingsScore_CannotExceed70() public {
        vm.prank(alice);
        savings.deposit(100_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.savingsScore, 70);

        assertLe(profile.savingsScore, 70);
    }

    /*//////////////////////////////////////////////////////////////
                    REPAYMENT SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RepaymentScore_IsZero() public view {
        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.repaymentScore, 0);
    }

    function test_RepaymentScore_RemainsZeroWithSavings() public {
        vm.prank(alice);
        savings.deposit(100_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.repaymentScore, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    OVERALL SCORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OverallScore_CombinesMembershipAndSavings() public {
        vm.warp(FIVE_YEARS);

        vm.prank(alice);
        savings.deposit(50_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.membershipScore, 30);

        assertEq(profile.savingsScore, 70);

        assertEq(profile.repaymentScore, 0);

        assertEq(profile.creditScore, 100);
    }

    function test_OverallScore_CannotExceed100() public {
        vm.warp(FIVE_YEARS);

        vm.prank(alice);
        savings.deposit(100_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.creditScore, 100);

        assertLe(profile.creditScore, 100);
    }

    /*//////////////////////////////////////////////////////////////
                        RISK TIER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RiskTier_VeryHigh() public view {
        assertEq(uint256(creditScore.getRiskTier(alice)), uint256(ICreditScore.RiskTier.VeryHigh));
    }

    function test_RiskTier_High() public {
        vm.warp(SIX_MONTHS);

        vm.prank(alice);
        savings.deposit(1_000e18);

        // Membership = 10
        // Savings = 45
        // Total = 55
        assertEq(creditScore.getCreditScore(alice), 55);

        assertEq(uint256(creditScore.getRiskTier(alice)), uint256(ICreditScore.RiskTier.High));
    }

    function test_RiskTier_Medium() public {
        vm.warp(ONE_YEAR);

        vm.prank(alice);
        savings.deposit(5_000e18);

        // Membership = 15
        // Savings = 60
        // Total = 75
        assertEq(creditScore.getCreditScore(alice), 75);

        assertEq(uint256(creditScore.getRiskTier(alice)), uint256(ICreditScore.RiskTier.Low));
    }

    function test_RiskTier_Low() public {
        vm.warp(TWO_YEARS);

        vm.prank(alice);
        savings.deposit(20_000e18);

        // Membership = 25
        // Savings = 65
        // Total = 90
        assertEq(creditScore.getCreditScore(alice), 90);

        assertEq(uint256(creditScore.getRiskTier(alice)), uint256(ICreditScore.RiskTier.VeryLow));
    }

    function test_RiskTier_VeryLow() public {
        vm.warp(FIVE_YEARS);

        vm.prank(alice);
        savings.deposit(50_000e18);

        assertEq(creditScore.getCreditScore(alice), 100);

        assertEq(uint256(creditScore.getRiskTier(alice)), uint256(ICreditScore.RiskTier.VeryLow));
    }

    /*//////////////////////////////////////////////////////////////
                    CREDIT PROFILE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetCreditProfile() public {
        vm.warp(TWO_YEARS);

        vm.prank(alice);
        savings.deposit(20_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(profile.creditScore, 90);

        assertEq(uint256(profile.riskTier), uint256(ICreditScore.RiskTier.VeryLow));

        assertEq(profile.membershipScore, 25);

        assertEq(profile.savingsScore, 65);

        assertEq(profile.repaymentScore, 0);

        assertEq(profile.calculatedAt, block.timestamp);
    }

    function test_GetCreditScoreMatchesProfile() public {
        vm.warp(ONE_YEAR);

        vm.prank(alice);
        savings.deposit(10_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(creditScore.getCreditScore(alice), profile.creditScore);
    }

    function test_GetRiskTierMatchesProfile() public {
        vm.warp(ONE_YEAR);

        vm.prank(alice);
        savings.deposit(10_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertEq(uint256(creditScore.getRiskTier(alice)), uint256(profile.riskTier));
    }

    /*//////////////////////////////////////////////////////////////
                    MEMBER VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertGetCreditProfile_NonMember() public {
        vm.expectRevert(ICoopVault.MemberNotFound.selector);

        creditScore.getCreditProfile(nonMember);
    }

    function test_RevertGetCreditScore_NonMember() public {
        vm.expectRevert(ICoopVault.MemberNotFound.selector);

        creditScore.getCreditScore(nonMember);
    }

    function test_RevertGetRiskTier_NonMember() public {
        vm.expectRevert(ICoopVault.MemberNotFound.selector);

        creditScore.getRiskTier(nonMember);
    }

    function test_RevertGetCreditProfile_InactiveMember() public {
        vm.prank(owner);
        coopVault.deactivateMember(alice);

        vm.expectRevert(CreditScore.MemberInactive.selector);

        creditScore.getCreditProfile(alice);
    }

    function test_RevertGetCreditScore_InactiveMember() public {
        vm.prank(owner);
        coopVault.deactivateMember(alice);

        vm.expectRevert(CreditScore.MemberInactive.selector);

        creditScore.getCreditScore(alice);
    }

    function test_RevertGetRiskTier_InactiveMember() public {
        vm.prank(owner);
        coopVault.deactivateMember(alice);

        vm.expectRevert(CreditScore.MemberInactive.selector);

        creditScore.getRiskTier(alice);
    }

    /*//////////////////////////////////////////////////////////////
                INACTIVE MEMBER SAVINGS HISTORY
    //////////////////////////////////////////////////////////////*/

    function test_InactiveMemberCannotAccessCreditProfile() public {
        vm.prank(alice);
        savings.deposit(10_000e18);

        vm.prank(owner);
        coopVault.deactivateMember(alice);

        assertTrue(coopVault.isMember(alice));

        assertFalse(coopVault.isActiveMember(alice));

        vm.expectRevert(CreditScore.MemberInactive.selector);

        creditScore.getCreditProfile(alice);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-MEMBER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MembersHaveIndependentCreditScores() public {
        vm.prank(alice);
        savings.deposit(1_000e18);

        vm.prank(bob);
        savings.deposit(50_000e18);

        uint256 aliceScore = creditScore.getCreditScore(alice);

        uint256 bobScore = creditScore.getCreditScore(bob);

        assertEq(aliceScore, 50);

        assertEq(bobScore, 75);

        assertTrue(aliceScore != bobScore);
    }

    function test_MembershipDurationAffectsMembersIndependently() public {
        vm.warp(SIX_MONTHS);

        uint256 aliceScore = creditScore.getCreditScore(alice);

        vm.warp(TWO_YEARS);

        uint256 bobScore = creditScore.getCreditScore(bob);

        assertEq(aliceScore, 10);

        assertEq(bobScore, 25);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CreditScoreNeverExceeds100(uint256 balance, uint256 deposited) public {
        balance = bound(balance, 0, INITIAL_BALANCE);

        deposited = bound(deposited, 0, INITIAL_BALANCE);

        vm.warp(FIVE_YEARS);

        if (deposited > 0) {
            vm.prank(alice);
            savings.deposit(deposited);

            if (deposited > balance) {
                vm.prank(alice);
                savings.withdraw(deposited - balance);
            }
        }

        uint256 score = creditScore.getCreditScore(alice);

        assertLe(score, 100);
    }

    function testFuzz_SavingsScoreNeverExceeds70(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_BALANCE);

        if (amount > 0) {
            vm.prank(alice);
            savings.deposit(amount);
        }

        uint256 savingsScore = creditScore.getCreditProfile(alice).savingsScore;

        assertLe(savingsScore, 70);
    }

    function testFuzz_RepaymentScoreAlwaysZero() public {
        uint256[] memory amounts = new uint256[](3);

        amounts[0] = 100e18;
        amounts[1] = 1_000e18;
        amounts[2] = 10_000e18;

        for (uint256 i = 0; i < amounts.length; i++) {
            vm.prank(alice);
            savings.deposit(amounts[i]);
        }

        assertEq(creditScore.getCreditProfile(alice).repaymentScore, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SCORE COMPONENT INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function test_CreditScoreEqualsComponents() public {
        vm.warp(TWO_YEARS);

        vm.prank(alice);
        savings.deposit(20_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        uint256 componentTotal = profile.membershipScore + profile.savingsScore + profile.repaymentScore;

        assertEq(profile.creditScore, componentTotal);
    }

    function test_CreditScoreComponentsRespectMaximums() public {
        vm.warp(FIVE_YEARS);

        vm.prank(alice);
        savings.deposit(100_000e18);

        ICreditScore.CreditProfile memory profile = creditScore.getCreditProfile(alice);

        assertLe(profile.membershipScore, 30);

        assertLe(profile.savingsScore, 70);

        assertEq(profile.repaymentScore, 0);

        assertLe(profile.creditScore, 100);
    }
}
