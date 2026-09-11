import { getMemberFinancialData } from "./graph";
import { formatUsdc, formatToken } from "./format";

export interface InvestmentRiskResult {
  member: string;

  totalPurchases: {
    amount: string;
    currency: string;
  };

  totalRedemptions: {
    amount: string;
    currency: string;
  };

  netInvestmentExposure: {
    amount: string;
    currency: string;
  };

  investmentTransactions: number;

  investmentPurchases: number;

  investmentRedemptions: number;

  investmentActivity: boolean;

  investmentRiskScore: number;

  investmentRiskLevel: "LOW" | "MEDIUM" | "HIGH";

  factors: string[];

  source: {
    provider: string;
    financialData: string;
    network: string;
  };
}

export async function calculateInvestmentRisk(
  wallet: string
): Promise<InvestmentRiskResult> {
  const data = await getMemberFinancialData(wallet);

  const purchases = data.investmentTransactions.filter(
    (tx) => tx.type === "PURCHASE"
  );

  const redemptions = data.investmentTransactions.filter(
    (tx) => tx.type === "REDEEM"
  );

  const totalPurchases = purchases.reduce(
    (sum, tx) => sum + BigInt(tx.usdcAmount),
    0n
  );

  const totalRedemptions = redemptions.reduce(
    (sum, tx) => sum + BigInt(tx.usdcAmount),
    0n
  );

  const netExposure =
    totalPurchases > totalRedemptions
      ? totalPurchases - totalRedemptions
      : 0n;

  const factors: string[] = [];

  let score = 100;

  const transactionCount =
    data.investmentTransactions.length;

  const hasInvestmentActivity = transactionCount > 0;

  /*
   * No investment activity is not necessarily risky.
   * We treat it as informational.
   */
  if (!hasInvestmentActivity) {
    factors.push(
      "Member has no recorded investment activity"
    );

    return {
      member: wallet,

      totalPurchases: formatUsdc(totalPurchases),

      totalRedemptions: formatUsdc(totalRedemptions),

      netInvestmentExposure: formatUsdc(netExposure),

      investmentTransactions: 0,

      investmentPurchases: 0,

      investmentRedemptions: 0,

      investmentActivity: false,

      investmentRiskScore: 100,

      investmentRiskLevel: "LOW",

      factors,

      source: {
        provider: "The Graph",
        financialData: "Live CoopChain subgraph",
        network: "Arc Testnet",
      },
    };
  }

  /*
   * Large net exposure relative to activity can indicate
   * concentration risk.
   */
  if (
    totalPurchases > 0n &&
    netExposure * 2n > totalPurchases
  ) {
    score -= 10;

    factors.push(
      "Member currently has meaningful net investment exposure"
    );
  }

  /*
   * Heavy investment activity without diversification
   * information should receive a moderate risk penalty.
   */
  if (transactionCount >= 5) {
    score -= 10;

    factors.push(
      "Member has high investment transaction activity"
    );
  }

  /*
   * If purchases are substantially larger than redemptions,
   * capital remains exposed to investments.
   */
  if (
    totalPurchases > 0n &&
    totalRedemptions * 4n < totalPurchases
  ) {
    score -= 10;

    factors.push(
      "Investment purchases substantially exceed redemptions"
    );
  }

  if (netExposure === 0n) {
    factors.push(
      "Member currently has no net investment exposure"
    );
  }

  if (factors.length === 0) {
    factors.push(
      "No significant investment risk factors detected"
    );
  }

  score = Math.max(0, Math.min(100, score));

  let riskLevel: "LOW" | "MEDIUM" | "HIGH";

  if (score >= 75) {
    riskLevel = "LOW";
  } else if (score >= 50) {
    riskLevel = "MEDIUM";
  } else {
    riskLevel = "HIGH";
  }

  return {
    member: wallet,

    totalPurchases: formatUsdc(totalPurchases),

    totalRedemptions: formatUsdc(totalRedemptions),

    netInvestmentExposure: formatUsdc(netExposure),

    investmentTransactions: transactionCount,

    investmentPurchases: purchases.length,

    investmentRedemptions: redemptions.length,

    investmentActivity: true,

    investmentRiskScore: score,

    investmentRiskLevel: riskLevel,

    factors,

    source: {
      provider: "The Graph",
      financialData: "Live CoopChain subgraph",
      network: "Arc Testnet",
    },
  };
}