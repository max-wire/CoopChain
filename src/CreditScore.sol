// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICoopVault} from "./interfaces/ICoopVault.sol";
import {ISavings} from "./interfaces/ISavings.sol";
import {ICreditScore} from "./interfaces/ICreditScore.sol";

/**
 * @title CreditScore
 * @author Maxwell Wire
 * @notice Calculates the creditworthiness of cooperative members.
 * @dev
 * Credit Score V1:
 * - Membership duration (30%)
 * - Savings behaviour (70%)
 * - Repayment history: 0% (reserved for future versions)
 *
 * The maximum credit score is 100 and is mapped to a corresponding
 * risk tier ranging from VeryLow to VeryHigh.
 */
contract CreditScore is ICreditScore {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MemberInactive();
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ICoopVault private immutable i_coopVault;
    ISavings private immutable i_savings;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant MAX_SCORE = 100;

    uint256 private constant MAX_MEMBERSHIP_SCORE = 30;
    uint256 private constant MAX_SAVINGS_SCORE = 70;

    // Membership thresholds
    uint256 private constant SIX_MONTHS = 180 days;
    uint256 private constant ONE_YEAR = 365 days;
    uint256 private constant TWO_YEARS = 730 days;
    uint256 private constant FIVE_YEARS = 1825 days;

    // Savings balance thresholds
    uint256 private constant BALANCE_SMALL = 1_000 ether;
    uint256 private constant BALANCE_MEDIUM = 5_000 ether;
    uint256 private constant BALANCE_LARGE = 10_000 ether;

    // Deposit thresholds
    uint256 private constant LOW_DEPOSIT = 5_000 ether;
    uint256 private constant MEDIUM_DEPOSIT = 20_000 ether;
    uint256 private constant HIGH_DEPOSIT = 50_000 ether;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the CreditScore contract.
     * @param coopVault Address of the CoopVault contract.
     * @param savings Address of the Savings contract.
     */
    constructor(address coopVault, address savings) {
        if (coopVault == address(0)) revert InvalidAddress();
        if (savings == address(0)) revert InvalidAddress();

        i_coopVault = ICoopVault(coopVault);
        i_savings = ISavings(savings);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ICreditScore
     */
    function getCreditProfile(address member) external view override returns (CreditProfile memory) {
        return _getCreditProfile(member);
    }

    /**
     * @inheritdoc ICreditScore
     */
    function getCreditScore(address member) external view override returns (uint256) {
        return _getCreditProfile(member).creditScore;
    }

    /**
     * @inheritdoc ICreditScore
     */
    function getRiskTier(address member) external view override returns (RiskTier) {
        return _getCreditProfile(member).riskTier;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SCORE HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the membership score based on membership duration.
     * @param coopMember Cooperative member information.
     * @return Membership score out of 30.
     */
    function _calculateMembershipScore(ICoopVault.Member memory coopMember) internal view returns (uint256) {
        uint256 duration = block.timestamp - coopMember.joinedAt;

        if (duration < SIX_MONTHS) return 5;
        if (duration < ONE_YEAR) return 10;
        if (duration < TWO_YEARS) return 15;
        if (duration < FIVE_YEARS) return 25;

        return MAX_MEMBERSHIP_SCORE;
    }

    /**
     * @notice Calculates the savings score of a member.
     * @param member Member wallet address.
     * @return Savings score out of 70.
     */
    function _calculateSavingsScore(address member) internal view returns (uint256) {
        ISavings.SavingsAccount memory account = i_savings.getSavingsAccount(member);

        uint256 score = _balanceScore(account.balance) + _depositScore(account.totalDeposited)
            + _disciplineScore(account.balance, account.totalDeposited);

        if (score > MAX_SAVINGS_SCORE) {
            score = MAX_SAVINGS_SCORE;
        }

        return score;
    }

    /**
     * @notice Calculates the balance component of the savings score.
     * @param balance Current savings balance.
     * @return Score awarded for savings balance.
     */
    function _balanceScore(uint256 balance) internal pure returns (uint256) {
        if (balance == 0) return 0;
        if (balance < BALANCE_SMALL) return 10;
        if (balance < BALANCE_MEDIUM) return 20;

        // BALANCE_LARGE and above
        return 30;
    }

    /**
     * @notice Calculates the deposit component of the savings score.
     * @param deposits Total amount deposited.
     * @return Score awarded for deposit activity.
     */
    function _depositScore(uint256 deposits) internal pure returns (uint256) {
        if (deposits == 0) return 0;
        if (deposits < LOW_DEPOSIT) return 5;
        if (deposits < MEDIUM_DEPOSIT) return 10;
        if (deposits < HIGH_DEPOSIT) return 15;

        return 20;
    }

    /**
     * @notice Calculates the savings discipline component.
     * @dev Uses the ratio of current balance to total deposited.
     * @param balance Current savings balance.
     * @param deposits Total deposits made.
     * @return Score awarded for savings discipline.
     */
    function _disciplineScore(uint256 balance, uint256 deposits) internal pure returns (uint256) {
        if (deposits == 0) return 0;

        uint256 ratio = balance * 100 / deposits;

        if (ratio >= 90) return 20;
        if (ratio >= 75) return 15;
        if (ratio >= 50) return 10;
        if (ratio >= 25) return 5;

        return 0;
    }

    /**
     * @notice Calculates the repayment score.
     * @dev Version 1 always returns zero because the loan module
     * has not yet been implemented.
     * @return Repayment score.
     */
    function _calculateRepaymentScore(address) internal pure returns (uint256) {
        // Version 1: loan module not implemented yet.
        return 0;
    }

    /**
     * @notice Calculates the overall credit score.
     * @param membershipScore Membership score.
     * @param savingsScore Savings score.
     * @param repaymentScore Repayment score.
     * @return Overall credit score.
     */
    function _calculateOverallScore(uint256 membershipScore, uint256 savingsScore, uint256 repaymentScore)
        internal
        pure
        returns (uint256)
    {
        return membershipScore + savingsScore + repaymentScore;
    }

    /**
     * @notice Determines the risk tier from a credit score.
     * @param score Credit score.
     * @return Risk tier corresponding to the score.
     */
    function _determineRiskTier(uint256 score) internal pure returns (RiskTier) {
        if (score >= 90) return RiskTier.VeryLow;
        if (score >= 75) return RiskTier.Low;
        if (score >= 60) return RiskTier.Medium;
        if (score >= 40) return RiskTier.High;

        return RiskTier.VeryHigh;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that a member is active.
     * @param member Member wallet address.
     * @return coopMember Member information retrieved from CoopVault.
     */
    function _validateMember(address member) internal view returns (ICoopVault.Member memory coopMember) {
        coopMember = i_coopVault.getMember(member);

        if (!coopMember.active) {
            revert MemberInactive();
        }
    }

    /**
     * @notice Computes the complete credit profile of a member.
     * @param member Member wallet address.
     * @return Complete credit profile.
     */
    function _getCreditProfile(address member) internal view returns (CreditProfile memory) {
        ICoopVault.Member memory coopMember = _validateMember(member);

        uint256 membershipScore = _calculateMembershipScore(coopMember);

        uint256 savingsScore = _calculateSavingsScore(member);

        uint256 repaymentScore = _calculateRepaymentScore(member);

        uint256 creditScore = _calculateOverallScore(membershipScore, savingsScore, repaymentScore);

        if (creditScore > MAX_SCORE) {
            creditScore = MAX_SCORE;
        }

        return CreditProfile({
            creditScore: creditScore,
            riskTier: _determineRiskTier(creditScore),
            membershipScore: membershipScore,
            savingsScore: savingsScore,
            repaymentScore: repaymentScore,
            calculatedAt: block.timestamp
        });
    }
}
