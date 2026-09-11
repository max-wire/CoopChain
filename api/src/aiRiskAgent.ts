import OpenAI from "openai";

import { calculateMemberRisk } from "./risk";
import { calculateInvestmentRisk } from "./investmentRisk";
import { evaluateLoanDecision } from "./loanDecision";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const OPENAI_MODEL =
  process.env.OPENAI_MODEL || "gpt-5.6-luna";

export interface RiskDriver {
  factor: string;
  severity: "HIGH" | "MEDIUM" | "LOW";
  evidence: string;
}

export interface AgentAnalysis {
  member: string;

  decision: "APPROVE" | "REVIEW" | "DECLINE";

  riskLevel: "LOW" | "MEDIUM" | "HIGH";

  summary: string;

  keyRiskDrivers: RiskDriver[];

  loanAnalysis: {
    requestedAmount: string;
    duration: number;
    projectedLoanToSavingsRatio: number;
    decision: string;
  };

  investmentPosition: {
    riskScore: number;
    riskLevel: string;
    netExposure: string;
    investmentActivity: boolean;
    summary: string;
  };

  recommendations: string[];

  confidence: "HIGH" | "MEDIUM" | "LOW";

  dataSources: string[];

  whatIfAnalysis: {
    requestedAmount: string;
    decision: string;
    explanation: string;
  }[];

  aiAnalysis?: {
    explanation: string;
    recommendations: string[];
    investmentAssessment: string;
    whatIfAnalysis: {
      requestedAmount: string;
      decision: string;
      explanation: string;
    }[];
  };
}

function determineRiskLevel(
  creditScore: number,
  financialRiskScore: number,
  investmentRiskScore: number,
  decision: string
): "LOW" | "MEDIUM" | "HIGH" {
  if (decision === "DECLINE") {
    return "HIGH";
  }

  const overallScore =
    creditScore * 0.4 +
    financialRiskScore * 0.4 +
    investmentRiskScore * 0.2;

  if (overallScore >= 75) {
    return "LOW";
  }

  if (overallScore >= 50) {
    return "MEDIUM";
  }

  return "HIGH";
}

function buildRiskDrivers(
  memberRisk: Awaited<ReturnType<typeof calculateMemberRisk>>,
  loanDecision: Awaited<ReturnType<typeof evaluateLoanDecision>>,
  investmentRisk: Awaited<ReturnType<typeof calculateInvestmentRisk>>
): RiskDriver[] {
  const drivers: RiskDriver[] = [];

  if (loanDecision.projectedLoanToSavingsRatio >= 3) {
    drivers.push({
      factor: "Loan-to-savings ratio",
      severity: "HIGH",
      evidence:
        `Projected borrowing would be ` +
        `${loanDecision.projectedLoanToSavingsRatio}x ` +
        `the member's savings.`,
    });
  } else if (loanDecision.projectedLoanToSavingsRatio > 2) {
    drivers.push({
      factor: "Loan-to-savings ratio",
      severity: "MEDIUM",
      evidence:
        `Projected borrowing would be ` +
        `${loanDecision.projectedLoanToSavingsRatio}x ` +
        `the member's savings.`,
    });
  }

  if (memberRisk.activeLoans > 0) {
    if (memberRisk.repaymentRate === 0) {
      drivers.push({
        factor: "Repayment history",
        severity: "HIGH",
        evidence:
          "The member has active borrowing with no recorded repayments.",
      });
    } else if (memberRisk.repaymentRate < 50) {
      drivers.push({
        factor: "Repayment history",
        severity: "MEDIUM",
        evidence:
          `Current repayment rate is ${memberRisk.repaymentRate}%.`,
      });
    }
  }

  if (memberRisk.creditScore < 40) {
    drivers.push({
      factor: "Credit score",
      severity: "HIGH",
      evidence:
        `Credit score is ${memberRisk.creditScore}, below the lending threshold.`,
    });
  } else if (memberRisk.creditScore < 75) {
    drivers.push({
      factor: "Credit score",
      severity: "MEDIUM",
      evidence:
        `Credit score is ${memberRisk.creditScore}, below the automatic approval threshold.`,
    });
  }

  if (memberRisk.activeLoans >= 2) {
    drivers.push({
      factor: "Multiple active loans",
      severity: "MEDIUM",
      evidence:
        `Member currently has ${memberRisk.activeLoans} active loans.`,
    });
  }

  if (investmentRisk.netInvestmentExposure.amount !== "0") {
    drivers.push({
      factor: "Investment exposure",
      severity: "LOW",
      evidence:
        `Member currently has ${investmentRisk.netInvestmentExposure.amount} ` +
        `${investmentRisk.netInvestmentExposure.currency} of net investment exposure.`,
    });
  }

  return drivers;
}

function buildRecommendations(
  memberRisk: Awaited<ReturnType<typeof calculateMemberRisk>>,
  loanDecision: Awaited<ReturnType<typeof evaluateLoanDecision>>,
  investmentRisk: Awaited<ReturnType<typeof calculateInvestmentRisk>>
): string[] {
  const recommendations: string[] = [];

  if (
    memberRisk.activeLoans > 0 &&
    memberRisk.repaymentRate === 0
  ) {
    recommendations.push(
      "Repay the existing loan before taking additional borrowing."
    );
  }

  if (loanDecision.projectedLoanToSavingsRatio > 2) {
    recommendations.push(
      "Increase savings to improve borrowing capacity."
    );
  }

  if (memberRisk.creditScore < 75) {
    recommendations.push(
      "Build a stronger repayment history to improve the credit score."
    );
  }

  if (investmentRisk.netInvestmentExposure.amount !== "0") {
    recommendations.push(
      "Monitor investment concentration alongside borrowing obligations."
    );
  }

  if (recommendations.length === 0) {
    recommendations.push(
      "Maintain the current savings and repayment profile."
    );
  }

  return recommendations;
}

/**
 * Generate deterministic what-if loan scenarios.
 *
 * The current requested amount is always included.
 * Additional scenarios test smaller borrowing amounts.
 */
async function buildWhatIfAnalysis(
  wallet: string,
  currentRequestedAmount: string,
  duration: number
) {
  const amounts = [
    currentRequestedAmount,
    "0.75",
    "0.5",
    "0.25",
  ];

  const uniqueAmounts = [
    ...new Set(amounts),
  ];

  const scenarios = [];

  for (const amount of uniqueAmounts) {
    const decision = await evaluateLoanDecision(
      wallet,
      amount,
      duration
    );

    scenarios.push({
      requestedAmount: amount,
      decision: decision.decision,
      projectedLoanExposure:
        decision.projectedLoanExposure.amount,
      projectedLoanToSavingsRatio:
        decision.projectedLoanToSavingsRatio,
      savingsBalance:
        decision.savingsBalance.amount,
    });
  }

  return scenarios;
}

async function generateAIAnalysis(
  memberRisk: Awaited<ReturnType<typeof calculateMemberRisk>>,
  investmentRisk: Awaited<ReturnType<typeof calculateInvestmentRisk>>,
  loanDecision: Awaited<ReturnType<typeof evaluateLoanDecision>>,
  riskLevel: "LOW" | "MEDIUM" | "HIGH",
  riskDrivers: RiskDriver[],
  whatIfScenarios: Awaited<
    ReturnType<typeof buildWhatIfAnalysis>
  >
) {
  const verifiedFacts = {
    creditScore: memberRisk.creditScore,
    creditRiskTier: memberRisk.creditRiskTier,

    financialRiskScore:
      memberRisk.financialRiskScore,

    financialRiskLevel:
      memberRisk.financialRiskLevel,

    savingsBalance:
      memberRisk.savingsBalance,

    activeLoans:
      memberRisk.activeLoans,

    totalBorrowed:
      memberRisk.totalBorrowed,

    totalRepaid:
      memberRisk.totalRepaid,

    repaymentRate:
      memberRisk.repaymentRate,

    requestedLoan:
      loanDecision.requestedAmount,

    duration:
      loanDecision.duration,

    projectedLoanExposure:
      loanDecision.projectedLoanExposure,

    projectedLoanToSavingsRatio:
      loanDecision.projectedLoanToSavingsRatio,

    deterministicDecision:
      loanDecision.decision,

    investmentRiskScore:
      investmentRisk.investmentRiskScore,

    investmentRiskLevel:
      investmentRisk.investmentRiskLevel,

    investmentActivity:
      investmentRisk.investmentActivity,

    netInvestmentExposure:
      investmentRisk.netInvestmentExposure,

    deterministicRiskLevel:
      riskLevel,

    riskDrivers,

    whatIfScenarios,
  };

  const response = await openai.responses.create({
    model: OPENAI_MODEL,

    instructions: `
You are CoopChain's AI Risk Analyst.

You analyze verified financial data produced by CoopChain's
deterministic risk engine.

IMPORTANT RULES:

1. Never change or override the deterministic loan decision.
2. Never invent financial facts.
3. Use only the supplied verified facts.
4. Explain why the deterministic decision was reached.
5. Identify the most important financial risks.
6. Discuss the member's investment position when relevant.
7. Provide practical recommendations.
8. Clearly distinguish facts from recommendations.
9. Do not claim that your analysis is a binding financial decision.
10. Return ONLY valid JSON matching the requested structure.
11. Use the supplied what-if scenarios to explain how changing the requested loan amount changes the deterministic lending decision.
12. Never invent additional scenario numbers.
13. Explain which scenario appears more sustainable based on the verified deterministic results.
`,

    input: JSON.stringify(verifiedFacts),

    text: {
      format: {
        type: "json_schema",
        name: "coopchain_risk_analysis",
        strict: true,
        schema: {
          type: "object",
          properties: {
            explanation: {
              type: "string",
            },

            recommendations: {
              type: "array",
              items: {
                type: "string",
              },
            },

            investmentAssessment: {
              type: "string",
            },

            whatIfAnalysis: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  requestedAmount: {
                    type: "string",
                  },

                  decision: {
                    type: "string",
                  },

                  explanation: {
                    type: "string",
                  },
                },

                required: [
                  "requestedAmount",
                  "decision",
                  "explanation",
                ],

                additionalProperties: false,
              },
            },
          },

          required: [
            "explanation",
            "recommendations",
            "investmentAssessment",
            "whatIfAnalysis",
          ],

          additionalProperties: false,
        },
      },
    },
  });

  if (!response.output_text) {
    throw new Error(
      "OpenAI returned an empty response"
    );
  }

  return JSON.parse(response.output_text) as {
    explanation: string;
    recommendations: string[];
    investmentAssessment: string;
    whatIfAnalysis: {
      requestedAmount: string;
      decision: string;
      explanation: string;
    }[];
  };
}

export async function analyzeMemberRisk(
  wallet: string,
  requestedAmount: string,
  duration: number
): Promise<AgentAnalysis> {
  const [
    memberRisk,
    investmentRisk,
    loanDecision,
  ] = await Promise.all([
    calculateMemberRisk(wallet),
    calculateInvestmentRisk(wallet),
    evaluateLoanDecision(
      wallet,
      requestedAmount,
      duration
    ),
  ]);

  const riskLevel = determineRiskLevel(
    memberRisk.creditScore,
    memberRisk.financialRiskScore,
    investmentRisk.investmentRiskScore,
    loanDecision.decision
  );

  const keyRiskDrivers = buildRiskDrivers(
    memberRisk,
    loanDecision,
    investmentRisk
  );

  const deterministicRecommendations =
    buildRecommendations(
      memberRisk,
      loanDecision,
      investmentRisk
    );

  const investmentSummary =
    investmentRisk.netInvestmentExposure.amount === "0"
      ? "The member has investment activity but currently has no net investment exposure."
      : `The member currently has ${investmentRisk.netInvestmentExposure.amount} ${investmentRisk.netInvestmentExposure.currency} of net investment exposure.`;

  const whatIfScenarios =
    await buildWhatIfAnalysis(
      wallet,
      requestedAmount,
      duration
    );

  /*
   * The deterministic engine remains authoritative.
   * AI only explains the verified result.
   */
  const aiAnalysis = await generateAIAnalysis(
    memberRisk,
    investmentRisk,
    loanDecision,
    riskLevel,
    keyRiskDrivers,
    whatIfScenarios
  );

  return {
    member: wallet,

    decision: loanDecision.decision,

    riskLevel,

    summary: aiAnalysis.explanation,

    keyRiskDrivers,

    loanAnalysis: {
      requestedAmount:
        loanDecision.requestedAmount.amount,

      duration,

      projectedLoanToSavingsRatio:
        loanDecision.projectedLoanToSavingsRatio,

      decision:
        loanDecision.decision,
    },

    investmentPosition: {
      riskScore:
        investmentRisk.investmentRiskScore,

      riskLevel:
        investmentRisk.investmentRiskLevel,

      netExposure:
        investmentRisk.netInvestmentExposure.amount,

      investmentActivity:
        investmentRisk.investmentActivity,

      summary:
        investmentSummary,
    },

    recommendations:
      aiAnalysis.recommendations.length > 0
        ? aiAnalysis.recommendations
        : deterministicRecommendations,

    confidence:
      keyRiskDrivers.length > 0
        ? "HIGH"
        : "MEDIUM",

    dataSources: [
      "The Graph",
      "CreditScore.sol",
      "CoopChain Risk Engine",
      "Investment Risk Engine",
      "OpenAI",
      "Arc Testnet",
    ],

    whatIfAnalysis:
      aiAnalysis.whatIfAnalysis,

    aiAnalysis,
  };
}