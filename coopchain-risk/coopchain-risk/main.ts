import {
  CronCapability,
  HTTPClient,
  handlerInTee,
  Runner,
  type TeeRuntime,
} from "@chainlink/cre-sdk";

import { json, ok } from "@chainlink/cre-sdk";

export type Config = {
  schedule: string;
  riskApiUrl: string;
  memberWallet: string;
};

type FinancialSnapshot = {
  creditScore: number;
  loanToSavingsRatio: number;
  repaymentRate: number;
};

type RiskResult = {
  riskTier: string;
  eligible: boolean;
};

export const onConfidentialRiskCheck = (
  runtime: TeeRuntime<Config>,
  _triggerOutput: unknown,
): RiskResult => {
  /*
   * Fetch CoopChain's verified financial snapshot.
   *
   * The request is performed from the confidential handler.
   */
  const http = new HTTPClient();

  const response = http
    .sendRequest(runtime, {
      url: `${runtime.config.riskApiUrl}/api/risk/member/${runtime.config.memberWallet}`,
      method: "GET",
    })
    .result();

  if (!ok(response)) {
    throw new Error(`Risk API failed with status ${response.statusCode}`);
  }

  /*
   * The Risk API returns:
   *
   * {
   *   success: true,
   *   data: {
   *     creditScore: 40,
   *     loanToSavingsRatio: 2,
   *     repaymentRate: 0
   *   }
   * }
   *
   * Therefore, the financial values must be read from payload.data.
   */
  const payload = json(response) as {
    success: boolean;
    data: {
      creditScore: number;
      loanToSavingsRatio: number;
      repaymentRate: number;
    };
  };

  if (!payload.success || !payload.data) {
    throw new Error("Invalid Risk API response");
  }

  const financialSnapshot: FinancialSnapshot = {
    creditScore: payload.data.creditScore,
    loanToSavingsRatio: payload.data.loanToSavingsRatio,
    repaymentRate: payload.data.repaymentRate,
  };

  /*
   * Confidential CoopChain policy.
   *
   * These thresholds remain inside the TEE.
   * They are intentionally NOT returned in the result.
   */
  const MIN_CREDIT_SCORE = 55;
  const MAX_LOAN_TO_SAVINGS = 2.5;
  const MIN_REPAYMENT_RATE = 60;

  const eligible =
    financialSnapshot.creditScore >= MIN_CREDIT_SCORE &&
    financialSnapshot.loanToSavingsRatio <= MAX_LOAN_TO_SAVINGS &&
    financialSnapshot.repaymentRate >= MIN_REPAYMENT_RATE;

  let riskTier: string;

  if (!eligible) {
    riskTier = "HIGH";
  } else if (
    financialSnapshot.creditScore < 75 ||
    financialSnapshot.loanToSavingsRatio > 1.5
  ) {
    riskTier = "MEDIUM";
  } else {
    riskTier = "LOW";
  }

  runtime.log(
    `Confidential CoopChain risk evaluation: ${riskTier}`,
  );

  return {
    riskTier,
    eligible,
  };
};

export const initWorkflow = (config: Config) => {
  const cron = new CronCapability();

  return [
    handlerInTee(
      cron.trigger({
        schedule: config.schedule,
      }),
      onConfidentialRiskCheck,
      [
        {
          tee: "nitro",
          regions: ["us-west-2"],
        },
      ],
    ),
  ];
};

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}