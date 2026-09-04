// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICreditScore
 * @author Maxwell Wire
 * @notice Interface for the CreditScore module used by CoopChain.
 * @dev
 * Calculates a member's creditworthiness based on their cooperative
 * membership history, savings behavior, and (in future versions)
 * loan repayment performance.
 *
 * Version 1 scoring breakdown:
 * - Membership Score: 30 points
 * - Savings Score: 70 points
 * - Repayment Score: 0 points (reserved for future loan module)
 *
 * The maximum credit score is 100.
 */
interface ICreditScore {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents the credit risk classification of a member.
     * @dev Lower risk tiers indicate stronger creditworthiness.
     */
    enum RiskTier {
        VeryLow,
        Low,
        Medium,
        High,
        VeryHigh
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Complete credit assessment for a cooperative member.
     * @param creditScore Overall credit score out of 100.
     * @param riskTier Risk classification derived from the credit score.
     * @param membershipScore Points earned from membership duration.
     * @param savingsScore Points earned from savings balance and discipline.
     * @param repaymentScore Points earned from loan repayment history.
     * @param calculatedAt Timestamp when the profile was calculated.
     */
    struct CreditProfile {
        uint256 creditScore;
        RiskTier riskTier;
        uint256 membershipScore;
        uint256 savingsScore;
        uint256 repaymentScore;
        uint256 calculatedAt;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the complete credit profile of a member.
     * @dev Reverts if the member is inactive or does not exist.
     * @param member Address of the cooperative member.
     * @return profile The member's credit profile.
     */
    function getCreditProfile(address member) external view returns (CreditProfile memory profile);

    /**
     * @notice Returns the overall credit score of a member.
     * @dev The returned value is between 0 and 100.
     * Reverts if the member is inactive or does not exist.
     * @param member Address of the cooperative member.
     * @return score The member's credit score.
     */
    function getCreditScore(address member) external view returns (uint256 score);

    /**
     * @notice Returns the risk tier assigned to a member.
     * @dev Risk tiers are derived from the overall credit score.
     * Reverts if the member is inactive or does not exist.
     * @param member Address of the cooperative member.
     * @return tier The member's risk classification.
     */
    function getRiskTier(address member) external view returns (RiskTier tier);
}
