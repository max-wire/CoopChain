import { ethers } from "ethers";

const RPC_URL = process.env.ARC_RPC_URL!;
const CREDIT_SCORE_ADDRESS =
  process.env.CREDIT_SCORE_ADDRESS!;

const CREDIT_SCORE_ABI = [
  "function getCreditScore(address member) view returns (uint256)",
  "function getRiskTier(address member) view returns (uint8)",
];

const provider = new ethers.JsonRpcProvider(RPC_URL);

const creditScore = new ethers.Contract(
  CREDIT_SCORE_ADDRESS,
  CREDIT_SCORE_ABI,
  provider
);

export interface CreditScoreData {
  score: number;
  riskTier: string;
}

function riskTierFromScore(score: number): string {
  if (score >= 90) return "VeryLow";
  if (score >= 75) return "Low";
  if (score >= 60) return "Medium";
  if (score >= 40) return "High";
  return "VeryHigh";
}

export async function getCreditScore(
  wallet: string
): Promise<CreditScoreData> {
  const scoreRaw = await creditScore.getCreditScore(wallet);

  const score = Number(scoreRaw);

  return {
    score,
    riskTier: riskTierFromScore(score),
  };
}