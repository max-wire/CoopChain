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

app.get("/", (_req, res) => {
  res.json({
    name: "CoopChain Risk API",
    status: "running",
    dataSource: "The Graph",
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
      error:
        error instanceof Error
          ? error.message
          : "Risk calculation failed",
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

app.post("/api/agent/analyze", async (req, res) => {
  try {
    const body = req.body ?? {};

    const wallet =
      typeof body.wallet === "string"
        ? body.wallet.trim()
        : "";

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

    if (
      !Number.isInteger(duration) ||
      duration <= 0
    ) {
      return res.status(400).json({
        success: false,
        error: "duration must be a positive integer",
      });
    }

    const analysis = await analyzeMemberRisk(
      wallet,
      requestedAmount,
      duration
    );

    return res.json({
      success: true,
      data: analysis,
    });
  } catch (error) {
    console.error("AI Risk Agent error:", error);

    return res.status(500).json({
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "AI risk analysis failed",
    });
  }
});

app.post("/api/loan/decision", async (req, res) => {
  try {
    const body = req.body ?? {};

    const wallet =
      typeof body.wallet === "string"
        ? body.wallet.trim()
        : "";

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

    if (
      !Number.isInteger(duration) ||
      duration <= 0
    ) {
      return res.status(400).json({
        success: false,
        error: "duration must be a positive integer",
      });
    }

    const decision = await evaluateLoanDecision(
      wallet,
      requestedAmount,
      duration
    );

    return res.json({
      success: true,
      data: decision,
    });
  } catch (error) {
    console.error("Loan decision error:", error);

    return res.status(500).json({
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Loan decision failed",
    });
  }
});

const PORT = Number(process.env.PORT || 4000);

app.listen(PORT, () => {
  console.log(`CoopChain Risk API running on port ${PORT}`);
});