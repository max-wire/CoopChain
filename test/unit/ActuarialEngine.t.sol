// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ActuarialEngine} from "../../src/ActuarialEngine.sol";
import {IActuarialEngine} from "../../src/interfaces/IActuarialEngine.sol";

contract ActuarialEngineTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    ActuarialEngine internal engine;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        engine = new ActuarialEngine();
    }

    /*//////////////////////////////////////////////////////////////
                        SIMPLE INTEREST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SimpleInterest() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_000; // 10%
        uint256 periods = 2;

        (uint256 interestEarned, uint256 totalAmount) = engine.simpleInterest(principal, annualRateBps, periods);

        assertEq(interestEarned, 2_000);
        assertEq(totalAmount, 12_000);
    }

    function test_SimpleInterest_OnePeriod() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_000; // 10%

        (uint256 interestEarned, uint256 totalAmount) = engine.simpleInterest(principal, annualRateBps, 1);

        assertEq(interestEarned, 1_000);
        assertEq(totalAmount, 11_000);
    }

    function test_RevertSimpleInterest_InvalidPrincipal() public {
        vm.expectRevert(IActuarialEngine.InvalidPrincipal.selector);

        engine.simpleInterest(0, 1_000, 1);
    }

    function test_RevertSimpleInterest_InvalidRate() public {
        vm.expectRevert(IActuarialEngine.InvalidRate.selector);

        engine.simpleInterest(10_000, 0, 1);
    }

    function test_RevertSimpleInterest_InvalidPeriods() public {
        vm.expectRevert(IActuarialEngine.InvalidPeriods.selector);

        engine.simpleInterest(10_000, 1_000, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOUND INTEREST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CompoundInterest() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_000; // 10%
        uint256 periods = 2;

        (uint256 interestEarned, uint256 totalAmount) = engine.compoundInterest(principal, annualRateBps, periods);

        // 10,000 × 1.1² = 12,100
        assertEq(totalAmount, 12_100);
        assertEq(interestEarned, 2_100);
    }

    function test_CompoundInterest_OnePeriod() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_000;

        (uint256 interestEarned, uint256 totalAmount) = engine.compoundInterest(principal, annualRateBps, 1);

        assertEq(totalAmount, 11_000);
        assertEq(interestEarned, 1_000);
    }

    function test_RevertCompoundInterest_InvalidPrincipal() public {
        vm.expectRevert(IActuarialEngine.InvalidPrincipal.selector);

        engine.compoundInterest(0, 1_000, 1);
    }

    function test_RevertCompoundInterest_InvalidRate() public {
        vm.expectRevert(IActuarialEngine.InvalidRate.selector);

        engine.compoundInterest(10_000, 0, 1);
    }

    function test_RevertCompoundInterest_InvalidPeriods() public {
        vm.expectRevert(IActuarialEngine.InvalidPeriods.selector);

        engine.compoundInterest(10_000, 1_000, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FUTURE VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FutureValue() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_000; // 10%
        uint256 periods = 2;

        uint256 futureValue_ = engine.futureValue(principal, annualRateBps, periods);

        // 10,000 × 1.1² = 12,100
        assertEq(futureValue_, 12_100);
    }

    function test_FutureValue_MatchesCompoundInterest() public view {
        uint256 principal = 100_000;
        uint256 annualRateBps = 750; // 7.5%
        uint256 periods = 5;

        uint256 futureValue_ = engine.futureValue(principal, annualRateBps, periods);

        (, uint256 compoundTotal) = engine.compoundInterest(principal, annualRateBps, periods);

        assertEq(futureValue_, compoundTotal);
    }

    function test_RevertFutureValue_InvalidPrincipal() public {
        vm.expectRevert(IActuarialEngine.InvalidPrincipal.selector);

        engine.futureValue(0, 1_000, 1);
    }

    function test_RevertFutureValue_InvalidRate() public {
        vm.expectRevert(IActuarialEngine.InvalidRate.selector);

        engine.futureValue(10_000, 0, 1);
    }

    function test_RevertFutureValue_InvalidPeriods() public {
        vm.expectRevert(IActuarialEngine.InvalidPeriods.selector);

        engine.futureValue(10_000, 1_000, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            PRESENT VALUE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PresentValue() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_000; // 10%
        uint256 periods = 2;

        uint256 futureValue_ = engine.futureValue(principal, annualRateBps, periods);

        uint256 presentValue_ = engine.presentValue(futureValue_, annualRateBps, periods);

        // Due to fixed-point rounding, allow a very small tolerance.
        assertApproxEqAbs(presentValue_, principal, 1);
    }

    function test_PresentValue_IsInverseOfFutureValue() public view {
        uint256 principal = 100_000;
        uint256 annualRateBps = 500; // 5%
        uint256 periods = 10;

        uint256 futureValue_ = engine.futureValue(principal, annualRateBps, periods);

        uint256 presentValue_ = engine.presentValue(futureValue_, annualRateBps, periods);

        assertApproxEqAbs(presentValue_, principal, 2);
    }

    function test_RevertPresentValue_InvalidFutureValue() public {
        vm.expectRevert(IActuarialEngine.InvalidPrincipal.selector);

        engine.presentValue(0, 1_000, 1);
    }

    function test_RevertPresentValue_InvalidRate() public {
        vm.expectRevert(IActuarialEngine.InvalidRate.selector);

        engine.presentValue(10_000, 0, 1);
    }

    function test_RevertPresentValue_InvalidPeriods() public {
        vm.expectRevert(IActuarialEngine.InvalidPeriods.selector);

        engine.presentValue(10_000, 1_000, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    MONTHLY PAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice
     * 10,000 principal
     * 12% annual nominal rate
     * 12 monthly payments
     *
     * Expected PMT ≈ 888.49
     * Expected total ≈ 10,661.88
     */
    function test_CalculateMonthlyPayment() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_200; // 12%
        uint256 months = 12;

        (uint256 monthlyPayment, uint256 totalRepayment) =
            engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertApproxEqAbs(monthlyPayment, 888, 1);
        assertApproxEqAbs(totalRepayment, 10_656, 12);
    }

    function test_CalculateMonthlyPayment_OneMonth() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_200; // 12%

        (uint256 monthlyPayment, uint256 totalRepayment) = engine.calculateMonthlyPayment(principal, annualRateBps, 1);

        // One month at 1%:
        // Payment = 10,000 × 1.01 = 10,100
        assertEq(monthlyPayment, 10_100);
        assertEq(totalRepayment, 10_100);
    }

    function test_CalculateMonthlyPayment_TwelveMonths() public view {
        uint256 principal = 100_000;
        uint256 annualRateBps = 1_200; // 12%
        uint256 months = 12;

        (uint256 monthlyPayment, uint256 totalRepayment) =
            engine.calculateMonthlyPayment(principal, annualRateBps, months);

        // Approximately 8,884.88 per month.
        assertApproxEqAbs(monthlyPayment, 8_884, 2);

        assertEq(totalRepayment, monthlyPayment * months);
    }

    function test_CalculateMonthlyPayment_LongTerm() public view {
        uint256 principal = 100_000;
        uint256 annualRateBps = 1_200; // 12%
        uint256 months = 60;

        (uint256 monthlyPayment, uint256 totalRepayment) =
            engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertGt(monthlyPayment, 0);
        assertGt(totalRepayment, principal);

        assertEq(totalRepayment, monthlyPayment * months);
    }

    function test_CalculateMonthlyPayment_HigherRate() public view {
        uint256 principal = 10_000;
        uint256 months = 12;

        (uint256 lowRatePayment,) =
            engine.calculateMonthlyPayment(
                principal,
                500, // 5%
                months
            );

        (uint256 highRatePayment,) =
            engine.calculateMonthlyPayment(
                principal,
                2_000, // 20%
                months
            );

        assertGt(highRatePayment, lowRatePayment);
    }

    function test_CalculateMonthlyPayment_LongTermCostsMore() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_200;

        (, uint256 shortTermRepayment) = engine.calculateMonthlyPayment(principal, annualRateBps, 12);

        (, uint256 longTermRepayment) = engine.calculateMonthlyPayment(principal, annualRateBps, 60);

        assertGt(longTermRepayment, shortTermRepayment);
    }

    function test_CalculateMonthlyPayment_IsGreaterThanPrincipalPerMonth() public view {
        uint256 principal = 10_000;
        uint256 annualRateBps = 1_200;
        uint256 months = 12;

        (uint256 monthlyPayment,) = engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertGt(monthlyPayment, principal / months);
    }

    function test_CalculateMonthlyPayment_TotalRepaymentExceedsPrincipal() public view {
        uint256 principal = 100_000;
        uint256 annualRateBps = 1_200;
        uint256 months = 24;

        (, uint256 totalRepayment) = engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertGt(totalRepayment, principal);
    }

    /*//////////////////////////////////////////////////////////////
                    MONTHLY PAYMENT REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertMonthlyPayment_InvalidPrincipal() public {
        vm.expectRevert(IActuarialEngine.InvalidPrincipal.selector);

        engine.calculateMonthlyPayment(0, 1_200, 12);
    }

    function test_RevertMonthlyPayment_InvalidRate() public {
        vm.expectRevert(IActuarialEngine.InvalidRate.selector);

        engine.calculateMonthlyPayment(10_000, 0, 12);
    }

    function test_RevertMonthlyPayment_InvalidMonths() public {
        vm.expectRevert(IActuarialEngine.InvalidPeriods.selector);

        engine.calculateMonthlyPayment(10_000, 1_200, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PAYMENT INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function test_MonthlyPayment_TotalRepaymentConsistency() public view {
        uint256 principal = 50_000;
        uint256 annualRateBps = 1_000;
        uint256 months = 36;

        (uint256 monthlyPayment, uint256 totalRepayment) =
            engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertEq(totalRepayment, monthlyPayment * months);
    }

    function test_MonthlyPayment_IsPositive() public view {
        uint256 principal = 1_000;
        uint256 annualRateBps = 100;
        uint256 months = 12;

        (uint256 monthlyPayment, uint256 totalRepayment) =
            engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertGt(monthlyPayment, 0);
        assertGt(totalRepayment, 0);
    }

    function test_MonthlyPayment_DecreasesWithLongerTerm() public view {
        uint256 principal = 100_000;
        uint256 annualRateBps = 1_200;

        (uint256 payment12,) = engine.calculateMonthlyPayment(principal, annualRateBps, 12);

        (uint256 payment24,) = engine.calculateMonthlyPayment(principal, annualRateBps, 24);

        (uint256 payment60,) = engine.calculateMonthlyPayment(principal, annualRateBps, 60);

        assertGt(payment12, payment24);
        assertGt(payment24, payment60);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SimpleInterest(uint256 principal, uint16 annualRateBps, uint16 periods) public view {
        principal = bound(principal, 1, 1e24);
        annualRateBps = uint16(bound(annualRateBps, 1, 5_000));
        periods = uint16(bound(periods, 1, 100));

        (uint256 interestEarned, uint256 totalAmount) = engine.simpleInterest(principal, annualRateBps, periods);

        assertEq(totalAmount, principal + interestEarned);

        assertGe(totalAmount, principal);
    }

    function testFuzz_CompoundInterest(uint256 principal, uint16 annualRateBps, uint8 periods) public view {
        principal = bound(principal, 1, 1e18);
        annualRateBps = uint16(bound(annualRateBps, 1, 2_000));
        periods = uint8(bound(periods, 1, 50));

        (uint256 interestEarned, uint256 totalAmount) = engine.compoundInterest(principal, annualRateBps, periods);

        assertEq(totalAmount, principal + interestEarned);

        assertGe(totalAmount, principal);
    }

    function testFuzz_FutureValue(uint256 principal, uint16 annualRateBps, uint8 periods) public view {
        principal = bound(principal, 1, 1e18);
        annualRateBps = uint16(bound(annualRateBps, 1, 2_000));
        periods = uint8(bound(periods, 1, 50));

        uint256 futureValue_ = engine.futureValue(principal, annualRateBps, periods);

        assertGe(futureValue_, principal);
    }

    function testFuzz_MonthlyPayment(uint256 principal, uint16 annualRateBps, uint16 months) public view {
        // Use economically meaningful loan amounts.
        // 1e18 = 1 whole token for an 18-decimal asset.
        principal = bound(principal, 1e18, 1_000_000e18);

        annualRateBps = uint16(bound(annualRateBps, 1, 2_000));

        months = uint16(bound(months, 1, 120));

        (uint256 monthlyPayment, uint256 totalRepayment) =
            engine.calculateMonthlyPayment(principal, annualRateBps, months);

        assertGt(monthlyPayment, 0);
        assertGt(totalRepayment, 0);

        assertEq(totalRepayment, monthlyPayment * months);

        assertGe(totalRepayment, principal);
    }

    function test_MonthlyPaymentCanRoundDownForTinyPrincipal() public view {
        (uint256 monthlyPayment, uint256 totalRepayment) = engine.calculateMonthlyPayment(12, 884, 15);

        assertEq(monthlyPayment, 0);
        assertEq(totalRepayment, 0);
    }
}
