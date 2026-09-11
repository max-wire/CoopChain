import { parseUnits } from "ethers";

import { calculateMemberRisk } from "./risk";
import { formatUsdc } from "./format";

export type LoanDecision =
  | "APPROVE"
  | "REVIEW"
  | "DECLINE";

export interface LoanDecisionResult {
  decision: LoanDecision;

  requestedAmount: {
    amount: string;
    currency: string;
  };

  duration: number;

  creditScore: number;
  creditRiskTier: string;

  financialRiskScore: number;
  financialRiskLevel: string;

  savingsBalance: {
    amount: string;
    currency: string;
  };

  currentLoanExposure: {
    amount: string;
    currency: string;
  };

  projectedLoanExposure: {
    amount: string;
    currency: string;
  };

  projectedLoanToSavingsRatio: number;

  reasons: string[];

  dataSources: string[];
}

export async function evaluateLoanDecision(
  wallet: string,
  requestedAmount: string,
  duration: number
): Promise<LoanDecisionResult> {
  const risk = await calculateMemberRisk(wallet);

  const requestedAmountRaw = parseUnits(requestedAmount, 6);

  const savingsRaw = parseUnits(
    risk.savingsBalance.amount,
    6
  );

  const currentBorrowedRaw = parseUnits(
    risk.totalBorrowed.amount,
    6
  );

  const projectedBorrowedRaw =
    currentBorrowedRaw + requestedAmountRaw;

  let projectedLoanToSavingsRatio = 0;

  if (savingsRaw > 0n) {
    projectedLoanToSavingsRatio =
      Number(projectedBorrowedRaw) / Number(savingsRaw);
  }

  const reasons: string[] = [];

  let decision: LoanDecision = "APPROVE";

  // --------------------------------------------------
  // Hard decline conditions
  // --------------------------------------------------

  if (!risk.active) {
    decision = "DECLINE";

    reasons.push(
      "Member account is inactive"
    );
  }

  if (risk.creditScore < 40) {
    decision = "DECLINE";

    reasons.push(
      "Credit score is below the minimum lending threshold"
    );
  }

  if (savingsRaw === 0n) {
    decision = "DECLINE";

    reasons.push(
      "Member has no savings balance to support the requested loan"
    );
  }

  if (projectedLoanToSavingsRatio >= 3) {
    decision = "DECLINE";

    reasons.push(
      "Projected borrowing would reach or exceed 3x the member's savings"
    );
  }

  // --------------------------------------------------
  // Review conditions
  // --------------------------------------------------

  if (decision !== "DECLINE") {
    if (risk.creditScore < 75) {
      decision = "REVIEW";

      reasons.push(
        "Credit score is below the automatic approval threshold"
      );
    }

    if (
      risk.activeLoans > 0 &&
      risk.repaymentRate < 50
    ) {
      decision = "REVIEW";

      reasons.push(
        "Existing loan repayment performance requires review"
      );
    }

    if (risk.activeLoans >= 2) {
      decision = "REVIEW";

      reasons.push(
        "Member already has multiple active loans"
      );
    }

    if (projectedLoanToSavingsRatio > 2) {
      decision = "REVIEW";

      reasons.push(
        "Projected borrowing would exceed 2x the member's savings"
      );
    }
  }

  // --------------------------------------------------
  // Automatic approval
  // --------------------------------------------------

  if (
    decision === "APPROVE" &&
    risk.creditScore >= 75 &&
    projectedLoanToSavingsRatio <= 1.5 &&
    (risk.activeLoans === 0 || risk.repaymentRate >= 50)
  ) {
    reasons.push(
      "Credit score meets the automatic approval threshold"
    );

    reasons.push(
      "Projected borrowing remains within the supported savings ratio"
    );

    if (risk.activeLoans === 0) {
      reasons.push(
        "Member has no existing active loans"
      );
    } else {
      reasons.push(
        "Existing loan repayment performance is acceptable"
      );
    }
  }

  // Fallback: anything that did not satisfy the approval
  // criteria should not accidentally become an approval.
  if (
    decision === "APPROVE" &&
    !(
      risk.creditScore >= 75 &&
      projectedLoanToSavingsRatio <= 1.5 &&
      (risk.activeLoans === 0 || risk.repaymentRate >= 50)
    )
  ) {
    decision = "REVIEW";

    reasons.push(
      "Loan does not meet all automatic approval criteria"
    );
  }

  return {
    decision,

    requestedAmount: formatUsdc(requestedAmountRaw),

    duration,

    creditScore: risk.creditScore,
    creditRiskTier: risk.creditRiskTier,

    financialRiskScore: risk.financialRiskScore,
    financialRiskLevel: risk.financialRiskLevel,

    savingsBalance: risk.savingsBalance,

    currentLoanExposure: formatUsdc(
      currentBorrowedRaw
    ),

    projectedLoanExposure: formatUsdc(
      projectedBorrowedRaw
    ),

    projectedLoanToSavingsRatio,

    reasons,

    dataSources: [
      "The Graph",
      "CreditScore.sol",
      "CoopChain Risk Engine",
      "Arc Testnet",
    ],
  };
}