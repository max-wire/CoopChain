import "dotenv/config";
import express from "express";
import cors from "cors";
import { parseUnits } from "ethers";

import { calculateMemberRisk } from "./risk";
import { calculateInvestmentRisk } from "./investmentRisk";
import { analyzeMemberRisk } from "./aiRiskAgent";
import { evaluateLoanDecision } from "./loanDecision";

const app = express();

app.use(cors());
app.use(express.json());

type ConfidentialRiskResult = {
  wallet: string;
  riskTier: "LOW" | "MEDIUM" | "HIGH";
  eligible: boolean;
  evaluatedAt: string;
};

// Latest Chainlink CRE result per wallet.
// This is intentionally kept in memory for the hackathon/demo.
// The CRE workflow only persists the final decision, not the
// confidential financial snapshot or policy thresholds.
const confidentialRiskResults = new Map<string, ConfidentialRiskResult>();

app.get("/", (_req, res) => {
  res.json({
    name: "CoopChain Risk API",
    status: "running",
    dataSource: "The Graph",
    chainlinkCRE: "active",
  });
});

app.get("/api/risk/member/:wallet", async (req, res) => {
  try {
    const { wallet } = req.params;

    if (!/^0x[a-fA-F0-9]{40}$/.test(wallet)) {
      return res.status(400).json({
        error: "Invalid Ethereum wallet address",
      });
    }

    const risk = await calculateMemberRisk(wallet);

    return res.json({
      success: true,
      data: risk,
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Risk calculation failed",
    });
  }
});

app.get("/api/risk/investment/:wallet", async (req, res) => {
  try {
    const { wallet } = req.params;

    if (!/^0x[a-fA-F0-9]{40}$/.test(wallet)) {
      return res.status(400).json({
        success: false,
        error: "Invalid Ethereum wallet address",
      });
    }

    const risk = await calculateInvestmentRisk(wallet);

    return res.json({
      success: true,
      data: risk,
    });
  } catch (error) {
    console.error("Investment risk error:", error);

    return res.status(500).json({
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Investment risk calculation failed",
    });
  }
});

/**

* Chainlink CRE callback
*
* CRE sends only the final confidential assessment here.
* No raw financial snapshot or policy thresholds are persisted.
  */
app.post("/api/risk/cre-result", (req, res) => {
  try {
    const body = req.body ?? {};

    const wallet = typeof body.wallet === "string" ? body.wallet.trim() : "";

    const riskTier =
      typeof body.riskTier === "string"
        ? body.riskTier.trim().toUpperCase()
        : "";

    const eligible = body.eligible;

    if (!/^0x[a-fA-F0-9]{40}$/.test(wallet)) {
      return res.status(400).json({
        success: false,
        error: "Invalid Ethereum wallet address",
      });
    }

    if (!["LOW", "MEDIUM", "HIGH"].includes(riskTier)) {
      return res.status(400).json({
        success: false,
        error: "riskTier must be LOW, MEDIUM, or HIGH",
      });
    }

    if (typeof eligible !== "boolean") {
      return res.status(400).json({
        success: false,
        error: "eligible must be a boolean",
      });
    }

    const result: ConfidentialRiskResult = {
      wallet,
      riskTier: riskTier as "LOW" | "MEDIUM" | "HIGH",
      eligible,
      evaluatedAt: new Date().toISOString(),
    };

    confidentialRiskResults.set(wallet.toLowerCase(), result);

    console.log(
      `Chainlink CRE result received: ${wallet} → ${result.riskTier} / eligible=${result.eligible}`,
    );

    return res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Chainlink CRE result error:", error);

    return res.status(500).json({
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Unable to store Chainlink CRE result",
    });
  }
});

/**

* Latest Chainlink CRE assessment for a member.
  */
app.get("/api/risk/cre/:wallet", (req, res) => {
  try {
    const { wallet } = req.params;

    if (!/^0x[a-fA-F0-9]{40}$/.test(wallet)) {
      return res.status(400).json({
        success: false,
        error: "Invalid Ethereum wallet address",
      });
    }

    const result = confidentialRiskResults.get(wallet.toLowerCase());

    if (!result) {
      return res.json({
        success: true,
        data: null,
      });
    }

    return res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Chainlink CRE lookup error:", error);

    return res.status(500).json({
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Unable to retrieve Chainlink CRE result",
    });
  }
});

app.post("/api/agent/analyze", async (req, res) => {
  try {
    const body = req.body ?? {};

    const wallet = typeof body.wallet === "string" ? body.wallet.trim() : "";

    const requestedAmount =
      typeof body.requestedAmount === "string"
        ? body.requestedAmount.trim()
        : "";

    const duration = body.duration;

    if (!/^0x[a-fA-F0-9]{40}$/.test(wallet)) {
      return res.status(400).json({
        success: false,
        error: "Invalid Ethereum wallet address",
      });
    }

    if (!requestedAmount) {
      return res.status(400).json({
        success: false,
        error: "requestedAmount must be a non-empty string",
      });
    }

    if (!Number.isInteger(duration) || duration <= 0) {
      return res.status(400).json({
        success: false,
        error: "duration must be a positive integer",
      });
    }

    const analysis = await analyzeMemberRisk(wallet, requestedAmount, duration);

    return res.json({
      success: true,
      data: analysis,
    });
  } catch (error) {
    console.error("AI Risk Agent error:", error);

    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "AI risk analysis failed",
    });
  }
});

app.post("/api/loan/decision", async (req, res) => {
  try {
    const body = req.body ?? {};

    const wallet = typeof body.wallet === "string" ? body.wallet.trim() : "";

    const requestedAmount =
      typeof body.requestedAmount === "string"
        ? body.requestedAmount.trim()
        : "";

    const duration = body.duration;

    if (!/^0x[a-fA-F0-9]{40}$/.test(wallet)) {
      return res.status(400).json({
        success: false,
        error: "Invalid Ethereum wallet address",
        received: wallet,
      });
    }

    if (requestedAmount === "") {
      return res.status(400).json({
        success: false,
        error: "requestedAmount must be a non-empty string",
      });
    }

    let parsedAmount;

    try {
      parsedAmount = parseUnits(requestedAmount, 6);
    } catch {
      return res.status(400).json({
        success: false,
        error: "requestedAmount must be a valid USDC amount",
      });
    }

    if (parsedAmount <= 0n) {
      return res.status(400).json({
        success: false,
        error: "requestedAmount must be greater than zero",
      });
    }

    if (!Number.isInteger(duration) || duration <= 0) {
      return res.status(400).json({
        success: false,
        error: "duration must be a positive integer",
      });
    }

    const decision = await evaluateLoanDecision(
      wallet,
      requestedAmount,
      duration,
    );

    return res.json({
      success: true,
      data: decision,
    });
  } catch (error) {
    console.error("Loan decision error:", error);

    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Loan decision failed",
    });
  }
});

const PORT = Number(process.env.PORT || 4000);

// Local development only — Vercel invokes the exported app directly.
if (process.env.VERCEL !== "1") {
  app.listen(PORT, () => {
    console.log(`CoopChain Risk API running on port ${PORT}`);
  });
}

export default app;
