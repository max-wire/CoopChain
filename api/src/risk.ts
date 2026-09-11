import { getMemberFinancialData } from "./graph";
import { getCreditScore } from "./creditScore";
import { formatUsdc } from "./format";

export async function calculateMemberRisk(wallet: string) {
  const data = await getMemberFinancialData(wallet);

  if (data.members.length === 0) {
    throw new Error("Member not found");
  }

  const member = data.members[0];

  const credit = await getCreditScore(wallet);

  const activeLoans = data.loans.filter(
    (loan) => loan.status === "ACTIVE"
  );

  const totalBorrowed = data.loans.reduce(
    (sum, loan) => sum + BigInt(loan.principal),
    0n
  );

  const totalRepaid = data.loans.reduce(
    (sum, loan) => sum + BigInt(loan.amountRepaid),
    0n
  );

  const savings = BigInt(member.savingsBalance);

  const repaymentRate =
    totalBorrowed === 0n
      ? 100
      : Number((totalRepaid * 10000n) / totalBorrowed) / 100;

  const loanToSavingsRatio =
    savings === 0n
      ? Number.POSITIVE_INFINITY
      : Number(totalBorrowed) / Number(savings);

  /*
   * ------------------------------------------------------------
   * Investment exposure
   * ------------------------------------------------------------
   *
   * PURCHASE increases exposure.
   * REDEEM decreases exposure.
   *
   * We calculate the net USDC value of investment activity
   * for this member instead of assuming that an Investment
   * registry record means the member owns the asset.
   */

  const investmentPurchases = data.investmentTransactions
    .filter((tx) => tx.type === "PURCHASE")
    .reduce(
      (sum, tx) => sum + BigInt(tx.usdcAmount),
      0n
    );

  const investmentRedemptions = data.investmentTransactions
    .filter((tx) => tx.type === "REDEEM")
    .reduce(
      (sum, tx) => sum + BigInt(tx.usdcAmount),
      0n
    );

  const netInvestmentExposure =
    investmentPurchases >= investmentRedemptions
      ? investmentPurchases - investmentRedemptions
      : 0n;

  const investmentActivity =
    data.investmentTransactions.length > 0;

  /*
   * ------------------------------------------------------------
   * Financial risk score
   * ------------------------------------------------------------
   *
   * This is intentionally separate from CreditScore.sol.
   *
   * CreditScore.sol:
   *   - membership
   *   - savings
   *   - repayment score
   *
   * This model:
   *   - current borrowing exposure
   *   - repayment behavior
   *   - active loan concentration
   *   - current investment exposure
   */

  let financialRiskScore = 100;

  const factors: string[] = [];

  // ------------------------------------------------------------
  // Loan / savings exposure
  // ------------------------------------------------------------

  if (loanToSavingsRatio > 2) {
    financialRiskScore -= 35;

    factors.push(
      "Total borrowing is more than 2x the member's savings"
    );
  } else if (loanToSavingsRatio > 1) {
    financialRiskScore -= 20;

    factors.push(
      "Total borrowing exceeds the member's savings"
    );
  } else if (loanToSavingsRatio > 0) {
    factors.push(
      "Total borrowing is within the member's savings balance"
    );
  }

  // ------------------------------------------------------------
  // Repayment behavior
  // ------------------------------------------------------------

  if (repaymentRate === 0 && activeLoans.length > 0) {
    financialRiskScore -= 25;

    factors.push(
      "No repayments have been recorded on active loans"
    );
  } else if (repaymentRate < 50) {
    financialRiskScore -= 15;

    factors.push(
      "Less than half of borrowed principal has been repaid"
    );
  } else if (repaymentRate >= 90) {
    factors.push(
      "Most borrowed principal has been repaid"
    );
  }

  // ------------------------------------------------------------
  // Active loan concentration
  // ------------------------------------------------------------

  if (activeLoans.length >= 2) {
    financialRiskScore -= 15;

    factors.push(
      "Member has multiple active loans"
    );
  } else if (activeLoans.length === 1) {
    factors.push(
      "Member currently has one active loan"
    );
  }

  // ------------------------------------------------------------
  // Investment exposure
  // ------------------------------------------------------------

  if (netInvestmentExposure > 0n) {
    factors.push(
      "Member currently has net investment exposure"
    );
  } else if (investmentActivity) {
    factors.push(
      "Member has investment activity but no current net exposure"
    );
  }

  // ------------------------------------------------------------
  // Clamp score
  // ------------------------------------------------------------

  financialRiskScore = Math.max(
    0,
    Math.min(100, financialRiskScore)
  );

  let financialRiskLevel:
    | "LOW"
    | "MEDIUM"
    | "HIGH";

  if (financialRiskScore >= 75) {
    financialRiskLevel = "LOW";
  } else if (financialRiskScore >= 50) {
    financialRiskLevel = "MEDIUM";
  } else {
    financialRiskLevel = "HIGH";
  }

  return {
    member: member.wallet,
    memberId: member.memberId,
    active: member.active,

    creditScore: credit.score,
    creditRiskTier: credit.riskTier,

    savingsBalance: formatUsdc(member.savingsBalance),

    activeLoans: activeLoans.length,
    totalBorrowed: formatUsdc(totalBorrowed),
    totalRepaid: formatUsdc(totalRepaid),

    repaymentRate,

    loanToSavingsRatio:
      Number.isFinite(loanToSavingsRatio)
        ? Number(loanToSavingsRatio.toFixed(4))
        : null,

    investmentActivity,
    investmentPurchases: formatUsdc(investmentPurchases),

    investmentRedemptions: formatUsdc(
      investmentRedemptions
    ),

    netInvestmentExposure: formatUsdc(
      netInvestmentExposure
    ),

    financialRiskScore,
    financialRiskLevel,

    factors,

    source: {
      provider: "The Graph + Arc",
      credit: "CreditScore.sol",
      financialData: "Live CoopChain subgraph",
      network: "Arc Testnet",
    },
  };
}
