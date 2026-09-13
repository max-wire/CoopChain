import { useEffect, useState } from "react";
import "./index.css";

const API_URL = import.meta.env.VITE_API_URL;
const WALLET = import.meta.env.VITE_MEMBER_WALLET;

type RiskDriver = {
  name: string;
  severity: string;
  description?: string;
  impact?: string;
};

type MemberRisk = {
  wallet: string;
  memberId?: string;
  active?: boolean;
  savingsBalance: number;
  creditScore: number;
  financialRisk: number;
  riskLevel: string;
  activeLoans: number;
  totalBorrowed: number;
  totalRepaid: number;
  repaymentRate?: number;
  loanToSavingsRatio?: number | null;
  creditRiskTier?: string;
  riskDrivers: RiskDriver[];
};

type LoanDecision = {
  decision: string;
  riskLevel: string;
  requestedAmount: number;
  durationMonths: number;
  creditScore?: number;
  creditRiskTier?: string;
  financialRiskScore?: number;
  savingsBalance?: number;
  currentLoanExposure?: number;
  projectedLoanExposure?: number;
  projectedLoanToSavingsRatio?: number;
  reasons: string[];
  dataSources: string[];
};

type ConfidentialRiskResult = {
  wallet: string;
  riskTier: "LOW" | "MEDIUM" | "HIGH";
  eligible: boolean;
  evaluatedAt: string;
};

type InvestmentRisk = {
  investment: {
    id?: string;
    name: string;
    symbol: string;
    assetType: unknown;
    token?: string;
    issuer?: string;
    price?: number;
    totalSupply?: number;
    active?: boolean;
  };

  position?: {
    amount?: number;
    value?: number;
    exposure?: number;
  };

  purchases?: number;
  redemptions?: number;
  transactions?: number;

  purchaseAmount?: number;
  redemptionAmount?: number;

  netExposure?: number;

  riskScore?: number;
  riskLevel?: string;
};

type WhatIfScenario = {
  amount: number;
  duration: number;
};

type ScenarioResult = {
  amount: number;
  duration: number;
  decision?: string;
  riskLevel?: string;
  projectedLoanToSavingsRatio?: number;
  projectedLoanExposure?: number;
  reasons?: string[];
  loading?: boolean;
};

type AIAnalysis = {
  summary?: string;
  explanation?: string;
  recommendations?: string[];
  riskLevel?: string;
  decision?: string;
  confidence?: string;
  drivers?: RiskDriver[];
  investmentAssessment?: string;
  loanAnalysis?: {
    requestedAmount?: string;
    duration?: number;
    projectedLoanToSavingsRatio?: number;
    decision?: string;
  };
  whatIfAnalysis?: {
    requestedAmount: string;
    decision: string;
    explanation: string;
  }[];
};

type MoneyValue =
  | number
  | string
  | null
  | undefined
  | {
      amount?: string | number;
      value?: string | number;
      currency?: string;
    };

function numericValue(value: unknown): number | undefined {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : undefined;
  }

  if (typeof value === "string") {
    const trimmed = value.trim();

    if (!trimmed) {
      return undefined;
    }

    const parsed = Number(trimmed);

    return Number.isFinite(parsed) ? parsed : undefined;
  }

  if (value && typeof value === "object") {
    const candidate = value as Record<string, unknown>;

    return numericValue(candidate.amount ?? candidate.value);
  }

  return undefined;
}

function safeNumber(value: unknown, fallback = 0): number {
  return numericValue(value) ?? fallback;
}

function normalizeDriver(value: unknown, index = 0): RiskDriver {
  if (typeof value === "string") {
    return {
      name: value,
      severity: "MEDIUM",
      description: value,
    };
  }

  if (value && typeof value === "object") {
    const item = value as Record<string, unknown>;

    return {
      name: String(
        item.name ?? item.title ?? item.factor ?? `Risk Factor ${index + 1}`,
      ),
      severity: String(item.severity ?? item.level ?? "MEDIUM"),
      description:
        item.description !== undefined
          ? String(item.description)
          : item.impact !== undefined
            ? String(item.impact)
            : undefined,
      impact: item.impact !== undefined ? String(item.impact) : undefined,
    };
  }

  return {
    name: `Risk Factor ${index + 1}`,
    severity: "MEDIUM",
    description: "Risk factor identified by the analysis engine.",
  };
}

function formatAssetType(value: unknown): string {
  if (typeof value === "string") {
    return value
      .replace(/_/g, " ")
      .replace(/\b\w/g, (char) => char.toUpperCase());
  }

  if (typeof value === "number") {
    const assetTypes: Record<number, string> = {
      0: "Equity",
      1: "Bond",
      2: "Fund",
      3: "Real Estate",
      4: "Receivable",
    };

    return assetTypes[value] ?? "Investment";
  }

  if (value && typeof value === "object") {
    const candidate = value as Record<string, unknown>;

    const nested =
      candidate.name ?? candidate.label ?? candidate.value ?? candidate.type;

    if (typeof nested === "string") {
      return nested
        .replace(/_/g, " ")
        .replace(/\b\w/g, (char) => char.toUpperCase());
    }
  }

  return "Investment";
}

function abbreviateWallet(wallet?: string) {
  if (!wallet) return "0x0000...0000";

  if (wallet.length < 12) {
    return wallet;
  }

  return `${wallet.slice(0, 6)}...${wallet.slice(-4)}`;
}

function money(value: MoneyValue) {
  const amount = numericValue(value);

  if (amount === undefined) {
    return "—";
  }

  return `${amount.toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 4,
  })} USDC`;
}

function plainNumber(value: MoneyValue) {
  const amount = numericValue(value);

  if (amount === undefined) {
    return "—";
  }

  return amount.toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 4,
  });
}

/*
 * UPDATED:
 * Hedera token values may arrive from the API as raw 18-decimal
 * token units. Keep already-human-readable values unchanged while
 * converting the large raw value currently returned by CCREF.
 */
function tokenSupply(value: MoneyValue) {
  const amount = numericValue(value);

  if (amount === undefined) {
    return "—";
  }

  const humanAmount = amount >= 1_000_000_000_000 ? amount / 1e18 : amount;

  return humanAmount.toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 4,
  });
}

function score(value?: number) {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return "—";
  }

  return `${Math.round(value)}/100`;
}

function decisionClass(decision?: string) {
  const value = decision?.toLowerCase() || "";

  if (
    value.includes("approve") ||
    value.includes("low") ||
    value.includes("yes")
  ) {
    return "success";
  }

  if (value.includes("review") || value.includes("medium")) {
    return "warning";
  }

  if (
    value.includes("decline") ||
    value.includes("high") ||
    value.includes("no")
  ) {
    return "danger";
  }

  return "";
}

function severityClass(severity?: string) {
  const value = severity?.toLowerCase() || "";

  if (value.includes("high") || value.includes("danger")) {
    return "danger";
  }

  if (value.includes("medium") || value.includes("warning")) {
    return "warning";
  }

  return "success";
}

function unwrapResponse(data: any): any {
  if (!data || typeof data !== "object") {
    return data;
  }

  return data.data ?? data.result ?? data.analysis ?? data;
}

function normalizeMemberResponse(data: any): MemberRisk | null {
  const root = unwrapResponse(data);

  if (!root || typeof root !== "object") {
    return null;
  }

  const rawDrivers = Array.isArray(root.factors)
    ? root.factors
    : Array.isArray(root.riskDrivers)
      ? root.riskDrivers
      : [];

  return {
    wallet: String(root.member ?? root.wallet ?? WALLET ?? ""),

    memberId: root.memberId !== undefined ? String(root.memberId) : undefined,

    active: typeof root.active === "boolean" ? root.active : undefined,

    savingsBalance: safeNumber(root.savingsBalance),

    creditScore: safeNumber(root.creditScore),

    financialRisk: safeNumber(root.financialRiskScore ?? root.financialRisk),

    riskLevel: String(root.financialRiskLevel ?? root.riskLevel ?? "PENDING"),

    activeLoans: safeNumber(root.activeLoans),

    totalBorrowed: safeNumber(root.totalBorrowed),

    totalRepaid: safeNumber(root.totalRepaid),

    repaymentRate: numericValue(root.repaymentRate),

    loanToSavingsRatio: numericValue(root.loanToSavingsRatio),

    creditRiskTier:
      root.creditRiskTier !== undefined
        ? String(root.creditRiskTier)
        : undefined,

    riskDrivers: rawDrivers.map((driver: unknown, index: number) =>
      normalizeDriver(driver, index),
    ),
  };
}

function normalizeLoanResponse(data: any): LoanDecision | null {
  const root = unwrapResponse(data);

  if (!root || typeof root !== "object") {
    return null;
  }

  return {
    decision: String(root.decision ?? "PENDING"),

    riskLevel: String(root.financialRiskLevel ?? root.riskLevel ?? "PENDING"),

    requestedAmount: safeNumber(root.requestedAmount),

    durationMonths: Math.max(
      1,
      Math.trunc(safeNumber(root.duration ?? root.durationMonths, 3)),
    ),

    creditScore: numericValue(root.creditScore),

    creditRiskTier:
      root.creditRiskTier !== undefined
        ? String(root.creditRiskTier)
        : undefined,

    financialRiskScore: numericValue(root.financialRiskScore),

    savingsBalance: numericValue(root.savingsBalance),

    currentLoanExposure: numericValue(root.currentLoanExposure),

    projectedLoanExposure: numericValue(root.projectedLoanExposure),

    projectedLoanToSavingsRatio: numericValue(root.projectedLoanToSavingsRatio),

    reasons: Array.isArray(root.reasons) ? root.reasons.map(String) : [],

    dataSources: Array.isArray(root.dataSources)
      ? root.dataSources.map(String)
      : [],
  };
}

function normalizeInvestmentResponse(data: any): InvestmentRisk | null {
  const root = unwrapResponse(data);

  if (!root || typeof root !== "object") {
    return null;
  }

  const investment = root.investment;

  if (!investment || typeof investment !== "object") {
    console.warn(
      "Investment response does not contain investment metadata:",
      data,
    );

    return null;
  }

  return {
    investment: {
      id: investment.investmentId ?? investment.id,

      name: investment.name ?? "Investment",

      symbol: investment.symbol ?? "—",

      assetType: investment.assetType ?? "Investment",

      token: investment.token,

      issuer: investment.issuer,

      price: numericValue(investment.price),

      totalSupply: numericValue(investment.totalSupply),

      active:
        typeof investment.active === "boolean" ? investment.active : undefined,
    },

    position: root.position ?? root.memberPosition ?? root.portfolioPosition,

    purchases: numericValue(root.investmentPurchases),

    redemptions: numericValue(root.investmentRedemptions),

    transactions: numericValue(root.investmentTransactions),

    purchaseAmount: numericValue(root.totalPurchases),

    redemptionAmount: numericValue(root.totalRedemptions),

    netExposure: numericValue(root.netInvestmentExposure),

    riskScore: numericValue(root.investmentRiskScore),

    riskLevel:
      root.investmentRiskLevel !== undefined
        ? String(root.investmentRiskLevel)
        : undefined,
  };
}

function normalizeAIResponse(data: any): AIAnalysis {
  const candidate = unwrapResponse(data);

  if (!candidate || typeof candidate !== "object") {
    return {};
  }

  const rawDrivers = Array.isArray(candidate.keyRiskDrivers)
    ? candidate.keyRiskDrivers
    : Array.isArray(candidate.drivers)
      ? candidate.drivers
      : Array.isArray(candidate.riskDrivers)
        ? candidate.riskDrivers
        : [];

  const rawWhatIf = Array.isArray(candidate.whatIfAnalysis)
    ? candidate.whatIfAnalysis
    : Array.isArray(candidate.aiAnalysis?.whatIfAnalysis)
      ? candidate.aiAnalysis.whatIfAnalysis
      : [];

  return {
    summary: candidate.summary ?? candidate.explanation ?? candidate.message,

    explanation: candidate.explanation ?? candidate.summary,

    recommendations: Array.isArray(candidate.recommendations)
      ? candidate.recommendations.map(String)
      : Array.isArray(candidate.aiAnalysis?.recommendations)
        ? candidate.aiAnalysis.recommendations.map(String)
        : [],

    riskLevel:
      candidate.riskLevel ?? candidate.risk_level ?? candidate.riskTier,

    decision: candidate.decision,

    confidence: candidate.confidence,

    drivers: rawDrivers.map((driver: unknown, index: number) =>
      normalizeDriver(driver, index),
    ),

    investmentAssessment:
      candidate.investmentPosition?.summary ??
      candidate.aiAnalysis?.investmentAssessment,

    loanAnalysis: candidate.loanAnalysis,

    whatIfAnalysis: rawWhatIf.map((scenario: any) => ({
      requestedAmount: String(scenario?.requestedAmount ?? "0"),
      decision: String(scenario?.decision ?? "PENDING"),
      explanation: String(
        scenario?.explanation ?? "No additional explanation was provided.",
      ),
    })),
  };
}

export default function App() {
  const [member, setMember] = useState<MemberRisk | null>(null);

  const [loan, setLoan] = useState<LoanDecision | null>(null);

  const [investment, setInvestment] = useState<InvestmentRisk | null>(null);

  const [creRisk, setCreRisk] = useState<ConfidentialRiskResult | null>(null);

  const [ai, setAi] = useState<AIAnalysis | null>(null);

  const [amount, setAmount] = useState("1");

  const duration = 3;

  const [selectedScenario, setSelectedScenario] = useState("1-3");

  const [scenarioResults, setScenarioResults] = useState<
    Record<string, ScenarioResult>
  >({});

  const [loading, setLoading] = useState(true);

  const [loanLoading, setLoanLoading] = useState(false);

  const [creLoading, setCreLoading] = useState(false);

  const [aiLoading, setAiLoading] = useState(false);

  const [error, setError] = useState("");

  const [showLoanForm, setShowLoanForm] = useState(false);

  const [showDepositForm, setShowDepositForm] = useState(false);

  async function loadConfidentialRisk() {
    if (!API_URL || !WALLET) {
      return null;
    }

    try {
      setCreLoading(true);

      const response = await fetch(`${API_URL}/api/risk/cre/${WALLET}`);

      const responseText = await response.text();

      if (!response.ok) {
        console.warn(
          "Chainlink CRE endpoint returned:",
          response.status,
          responseText,
        );

        setCreRisk(null);

        return null;
      }

      let data: any;

      try {
        data = JSON.parse(responseText);
      } catch {
        console.error(
          "Chainlink CRE endpoint returned invalid JSON:",
          responseText,
        );

        setCreRisk(null);

        return null;
      }

      console.log("Chainlink CRE response:", data);

      const normalized = unwrapResponse(data);

      if (!normalized || typeof normalized !== "object") {
        setCreRisk(null);

        return null;
      }

      if (!normalized.wallet || !normalized.riskTier) {
        setCreRisk(null);

        return null;
      }

      setCreRisk({
        wallet: String(normalized.wallet),
        riskTier: normalized.riskTier,
        eligible: normalized.eligible === true,
        evaluatedAt: String(normalized.evaluatedAt ?? ""),
      });

      return normalized;
    } catch (err) {
      console.error("Chainlink CRE request failed:", err);

      setCreRisk(null);

      return null;
    } finally {
      setCreLoading(false);
    }
  }

  async function analyzeLoan(
    requestedAmount: number,
    requestedDuration: number,
  ) {
    try {
      setLoanLoading(true);

      const cleanAmount = Number(requestedAmount);

      const cleanDuration = Math.trunc(Number(requestedDuration));

      if (!Number.isFinite(cleanAmount) || cleanAmount <= 0) {
        console.error("Invalid loan amount:", requestedAmount);

        return null;
      }

      if (!Number.isInteger(cleanDuration) || cleanDuration <= 0) {
        console.error("Invalid loan duration:", requestedDuration);

        return null;
      }

      const payload = {
        wallet: WALLET,
        requestedAmount: cleanAmount.toString(),
        duration: cleanDuration,
      };

      console.log("Loan decision request:", JSON.stringify(payload));

      const response = await fetch(`${API_URL}/api/loan/decision`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const responseText = await response.text();

      if (!response.ok) {
        console.error(
          "Loan decision API error:",
          response.status,
          responseText,
        );

        setLoan(null);

        return null;
      }

      let data: any;

      try {
        data = JSON.parse(responseText);
      } catch {
        console.error("Loan decision API returned invalid JSON:", responseText);

        setLoan(null);

        return null;
      }

      console.log("Loan decision response:", data);

      const normalized = normalizeLoanResponse(data);

      if (!normalized) {
        setLoan(null);

        return null;
      }

      setLoan(normalized);

      return normalized;
    } catch (err) {
      console.error("Loan analysis request failed:", err);

      setLoan(null);

      return null;
    } finally {
      setLoanLoading(false);
    }
  }

  async function analyzeScenario(scenario: WhatIfScenario) {
    const id = `${scenario.amount}-${scenario.duration}`;

    setScenarioResults((previous) => ({
      ...previous,
      [id]: {
        amount: scenario.amount,
        duration: scenario.duration,
        loading: true,
      },
    }));

    try {
      const result = await analyzeLoan(scenario.amount, scenario.duration);

      setScenarioResults((previous) => ({
        ...previous,
        [id]: {
          amount: scenario.amount,
          duration: scenario.duration,
          loading: false,
          decision: result?.decision,
          riskLevel: result?.riskLevel,
          projectedLoanToSavingsRatio: result?.projectedLoanToSavingsRatio,
          projectedLoanExposure: result?.projectedLoanExposure,
          reasons: result?.reasons ?? [],
        },
      }));

      return result;
    } catch (err) {
      console.error("Scenario analysis failed:", err);

      setScenarioResults((previous) => ({
        ...previous,
        [id]: {
          amount: scenario.amount,
          duration: scenario.duration,
          loading: false,
          decision: "ERROR",
        },
      }));

      return null;
    }
  }

  async function runAI() {
    try {
      setAiLoading(true);

      const parsedAmount = Number(amount);

      const cleanAmount =
        Number.isFinite(parsedAmount) && parsedAmount > 0 ? parsedAmount : 1;

      /*
       * UPDATED:
       * Use the currently selected scenario duration when one exists.
       * This prevents the AI panel from displaying a different term
       * from the loan scenario currently being demonstrated.
       */
      const selectedDuration = currentScenario?.duration ?? duration;

      const cleanDuration = Math.trunc(Number(selectedDuration));

      const payload = {
        wallet: WALLET,
        requestedAmount: cleanAmount.toString(),
        duration: cleanDuration,
      };

      console.log("AI Risk Agent request:", JSON.stringify(payload));

      const response = await fetch(`${API_URL}/api/agent/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const responseText = await response.text();

      if (!response.ok) {
        console.error("AI Risk Agent error:", response.status, responseText);

        throw new Error(
          `AI analysis failed (${response.status}): ${responseText}`,
        );
      }

      let data: any;

      try {
        data = JSON.parse(responseText);
      } catch {
        throw new Error("AI Risk Agent returned invalid JSON.");
      }

      console.log("AI Risk Agent response:", data);

      const normalized = normalizeAIResponse(data);

      setAi(normalized);
    } catch (err) {
      console.error("AI Risk Agent request failed:", err);

      setAi({
        summary:
          "The AI Risk Agent could not complete the analysis. Check the API response and run the analysis again.",
        riskLevel: "UNAVAILABLE",
        recommendations: [
          "Verify that the CoopChain Risk API is running.",
          "Verify the configured member wallet.",
          "Run the deterministic loan analysis first.",
        ],
      });
    } finally {
      setAiLoading(false);
    }
  }

  async function loadDashboard() {
    try {
      setLoading(true);
      setError("");

      if (!API_URL || !WALLET) {
        throw new Error("API URL or member wallet is not configured.");
      }

      const [memberResponse, investmentResponse, creResponse] =
        await Promise.all([
          fetch(`${API_URL}/api/risk/member/${WALLET}`),
          fetch(`${API_URL}/api/risk/investment/${WALLET}`),
          fetch(`${API_URL}/api/risk/cre/${WALLET}`),
        ]);

      if (!memberResponse.ok) {
        const text = await memberResponse.text();

        throw new Error(
          `Unable to load member risk data (${memberResponse.status}): ${text}`,
        );
      }

      const memberData = await memberResponse.json();

      console.log("Member risk response:", memberData);

      const normalizedMember = normalizeMemberResponse(memberData);

      if (!normalizedMember) {
        throw new Error("Member risk response could not be normalized.");
      }

      setMember(normalizedMember);

      if (investmentResponse.ok) {
        const investmentData = await investmentResponse.json();

        console.log("Investment risk response:", investmentData);

        const normalizedInvestment =
          normalizeInvestmentResponse(investmentData);

        console.log("Normalized investment:", normalizedInvestment);

        setInvestment(normalizedInvestment);
      } else {
        const text = await investmentResponse.text();

        console.warn(
          "Investment risk endpoint returned:",
          investmentResponse.status,
          text,
        );

        setInvestment(null);
      }

      if (creResponse.ok) {
        const creData = await creResponse.json();

        console.log("Chainlink CRE response:", creData);

        const normalizedCRE = unwrapResponse(creData);

        if (
          normalizedCRE &&
          typeof normalizedCRE === "object" &&
          normalizedCRE.wallet
        ) {
          setCreRisk({
            wallet: String(normalizedCRE.wallet),
            riskTier: normalizedCRE.riskTier,
            eligible: normalizedCRE.eligible === true,
            evaluatedAt: String(normalizedCRE.evaluatedAt ?? ""),
          });
        } else {
          setCreRisk(null);
        }
      } else {
        const text = await creResponse.text();

        console.warn(
          "Chainlink CRE endpoint returned:",
          creResponse.status,
          text,
        );

        setCreRisk(null);
      }

      const initialAmount = Number(amount);

      if (Number.isFinite(initialAmount) && initialAmount > 0) {
        const initialLoan = await analyzeLoan(initialAmount, duration);

        if (initialLoan) {
          setScenarioResults((previous) => ({
            ...previous,
            [`${initialAmount}-${duration}`]: {
              amount: initialAmount,
              duration,
              decision: initialLoan.decision,
              riskLevel: initialLoan.riskLevel,
              projectedLoanToSavingsRatio:
                initialLoan.projectedLoanToSavingsRatio,
              projectedLoanExposure: initialLoan.projectedLoanExposure,
              reasons: initialLoan.reasons,
              loading: false,
            },
          }));
        }
      }
    } catch (err) {
      console.error(err);

      setError(
        err instanceof Error ? err.message : "Unable to load CoopChain data.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (API_URL && WALLET) {
      loadDashboard();

      const creInterval = window.setInterval(() => {
        loadConfidentialRisk();
      }, 30000);

      return () => {
        window.clearInterval(creInterval);
      };
    }

    setLoading(false);

    setError("API URL or member wallet is not configured.");

    return undefined;
  }, []);

  function submitLoanAnalysis(event: React.FormEvent) {
    event.preventDefault();

    const requestedAmount = Number(amount);

    if (!Number.isFinite(requestedAmount) || requestedAmount <= 0) {
      return;
    }

    const scenario = {
      amount: requestedAmount,
      duration,
    };

    const id = `${scenario.amount}-${scenario.duration}`;

    setSelectedScenario(id);

    analyzeScenario(scenario);

    setShowLoanForm(false);
  }

  const scenarios: WhatIfScenario[] = [
    {
      amount: 1,
      duration: 3,
    },
    {
      amount: 0.5,
      duration: 3,
    },
    {
      amount: 1,
      duration: 6,
    },
    {
      amount: 2,
      duration: 6,
    },
  ];

  const currentScenario = scenarios.find(
    (scenario) =>
      `${scenario.amount}-${scenario.duration}` === selectedScenario,
  );

  const currentScenarioResult = scenarioResults[selectedScenario];

  const hasActiveLoan = !!member && Number(member.activeLoans || 0) > 0;

  const activeLoan = hasActiveLoan
    ? {
        principal: member?.totalBorrowed || 0,
        repaid: member?.totalRepaid || 0,
        status: "ACTIVE",
      }
    : null;

  const investmentProduct = investment?.investment;

  const investmentName =
    investmentProduct?.name || "Investment product unavailable";

  const investmentSymbol = investmentProduct?.symbol || "—";

  const investmentAssetType = formatAssetType(investmentProduct?.assetType);

  const investmentRiskScore = investment?.riskScore;

  const investmentRiskLevel = investment?.riskLevel || "—";

  const investmentNetExposure =
    investment?.netExposure ?? investment?.position?.exposure;

  const investmentPurchases = investment?.purchases;

  const investmentRedemptions = investment?.redemptions;

  const investmentTransactions = investment?.transactions;

  const investmentPurchaseAmount = investment?.purchaseAmount;

  const investmentRedemptionAmount = investment?.redemptionAmount;

  const creRiskTier = creRisk?.riskTier;

  const creEligible = creRisk?.eligible;

  const creDecisionClass = creRiskTier ? severityClass(creRiskTier) : "";

  const formattedCRETime = creRisk?.evaluatedAt
    ? new Date(creRisk.evaluatedAt).toLocaleString()
    : "Awaiting evaluation";

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand-block">
          <div className="brand-mark">C</div>

          <div>
            <div className="brand-name">COOPCHAIN</div>

            <div className="brand-subtitle">Financial Infrastructure</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          <div className="nav-label">MAIN</div>

          <a href="#command-center" className="nav-item active">
            <span className="nav-icon">⌂</span>
            <span>Command Center</span>
          </a>

          <a href="#members" className="nav-item">
            <span className="nav-icon">◉</span>
            <span>Members</span>
          </a>

          <a href="#savings" className="nav-item">
            <span className="nav-icon">＋</span>
            <span>Savings</span>
          </a>

          <a href="#loans" className="nav-item">
            <span className="nav-icon">↗</span>
            <span>Loans</span>
          </a>

          <a href="#investments" className="nav-item">
            <span className="nav-icon">◈</span>
            <span>Investments</span>
          </a>

          <a href="#risk" className="nav-item">
            <span className="nav-icon">⌁</span>
            <span>Risk & Intelligence</span>
          </a>

          <div className="nav-divider" />

          <div className="nav-label">INFRASTRUCTURE</div>

          <a href="#core-layers" className="nav-item">
            <span className="nav-icon">◇</span>
            <span>Core Layers</span>
          </a>

          <a href="#integrations" className="nav-item">
            <span className="nav-icon">⬡</span>
            <span>Integrations</span>
          </a>

          <a href="#network" className="nav-item">
            <span className="nav-icon">◎</span>
            <span>Network</span>
          </a>
        </nav>

        <div className="sidebar-footer">
          <div className="network-mini">
            <span className="status-dot" />

            <div>
              <strong>Arc Testnet</strong>

              <span>Connected</span>
            </div>
          </div>

          <div className="wallet-mini">{abbreviateWallet(WALLET)}</div>
        </div>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <div>
            <div className="mobile-brand">COOPCHAIN</div>

            <span className="topbar-context">
              Onchain Cooperative Financial Infrastructure
            </span>
          </div>

          <div className="topbar-right">
            <div className="network-status">
              <span className="status-dot" />
              ARC TESTNET
            </div>

            <div className="wallet-address">{abbreviateWallet(WALLET)}</div>
          </div>
        </header>

        {error && (
          <div className="error-banner">
            <span>!</span>

            <div>
              <strong>Data connection issue</strong>

              <p>{error}</p>
            </div>
          </div>
        )}

        <section id="command-center" className="page-section hero-section">
          <div className="hero-copy">
            <span className="eyebrow">
              ONCHAIN COOPERATIVE FINANCIAL INFRASTRUCTURE
            </span>

            <h1>CoopChain Command Center</h1>

            <p>
              A cooperative financial infrastructure connecting savings, credit,
              lending, tokenized investments and intelligent risk analysis
              onchain.
            </p>
          </div>

          <div className="hero-status-card">
            <div className="status-card-header">
              <span>NETWORK STATUS</span>

              <span className="live-pill">
                <span className="status-dot" />
                LIVE
              </span>
            </div>

            <div className="hero-network">ARC TESTNET</div>

            <div className="hero-wallet">
              <span>Member wallet</span>

              <strong>{abbreviateWallet(WALLET)}</strong>
            </div>
          </div>
        </section>

        <section id="core-layers" className="page-section">
          <div className="section-heading">
            <div>
              <span className="section-eyebrow">COOPERATIVE ENGINE</span>

              <h2>Core Cooperative Layers</h2>

              <p>
                The financial primitives that power the CoopChain member
                experience.
              </p>
            </div>
          </div>

          <div className="architecture-grid">
            {[
              ["01", "Membership", "Member identity & participation"],
              ["02", "CoopVault", "Cooperative financial foundation"],
              ["03", "Savings", "Member savings balances"],
              ["04", "CreditScore", "Onchain credit assessment"],
              ["05", "ActuarialEngine", "Loan payment calculations"],
              ["06", "LoanEngine", "Credit decisions & repayment"],
              ["07", "InvestmentRegistry", "Tokenized investment products"],
              ["08", "InvestmentPool", "Member investment positions"],
            ].map(([number, title, description]) => (
              <div className="architecture-card" key={number}>
                <div className="architecture-icon">{number}</div>

                <strong>{title}</strong>

                <span>{description}</span>

                <small>ACTIVE</small>
              </div>
            ))}
          </div>
        </section>

        <section id="integrations" className="page-section">
          <div className="section-heading">
            <div>
              <span className="section-eyebrow">EXTERNAL INFRASTRUCTURE</span>

              <h2>Connected Infrastructure</h2>

              <p>
                External networks and intelligence services extending the
                CoopChain protocol.
              </p>
            </div>
          </div>

          <div className="integration-grid">
            {[
              ["A", "Arc", "USDC settlement & treasury", "ARC TESTNET"],
              ["H", "Hedera", "Tokenized investment assets", "CCREF · TESTNET"],
              ["C", "Chainlink", "Confidential risk workflows", "CRE"],
              ["G", "The Graph", "Indexed blockchain data", "SUBGRAPH"],
              [
                "AI",
                "AI Risk Agent",
                "Financial intelligence",
                "ANALYSIS ENGINE",
              ],
            ].map(([icon, title, description, label]) => (
              <div className="integration-card" key={title}>
                <div className="integration-top">
                  <span className="integration-logo">{icon}</span>

                  <span className="connected-badge">CONNECTED</span>
                </div>

                <strong>{title}</strong>

                <span>{description}</span>

                <small>{label}</small>
              </div>
            ))}
          </div>
        </section>

        <section id="members" className="page-section">
          <div className="section-heading section-heading-inline">
            <div>
              <span className="section-eyebrow">MEMBERSHIP</span>

              <h2>Member Registry</h2>

              <p>
                CoopChain members connected to the financial infrastructure.
              </p>
            </div>

            <button className="secondary-button">+ Register Member</button>
          </div>

          <div className="member-card">
            <div className="member-identity">
              <div className="member-avatar">01</div>

              <div>
                <span className="member-label">MEMBER</span>

                <h3>Member #1</h3>

                <code>{WALLET || "Wallet not configured"}</code>
              </div>
            </div>

            <div className="member-state">
              <span className="active-badge">
                <span className="status-dot" />
                ACTIVE
              </span>

              <a href="#savings" className="text-link">
                View Profile →
              </a>
            </div>
          </div>
        </section>

        <section className="page-section overview-section">
          <div className="section-heading">
            <div>
              <span className="section-eyebrow">MEMBER #1</span>

              <h2>CoopChain Overview</h2>

              <p>
                A consolidated view of the member's cooperative financial
                position.
              </p>
            </div>
          </div>

          <div className="overview-grid">
            <div className="overview-card">
              <span>SAVINGS</span>

              <strong>{loading ? "—" : money(member?.savingsBalance)}</strong>

              <small>USDC balance</small>
            </div>

            <div className="overview-card">
              <span>CREDIT SCORE</span>

              <strong>{loading ? "—" : score(member?.creditScore)}</strong>

              <small>Current score</small>
            </div>

            <div className="overview-card">
              <span>ACTIVE LOANS</span>

              <strong>{loading ? "—" : (member?.activeLoans ?? 0)}</strong>

              <small>Outstanding positions</small>
            </div>

            <div className="overview-card">
              <span>INVESTMENTS</span>

              <strong>{investmentSymbol}</strong>

              <small>
                {investmentProduct?.name || "No investment position"}
              </small>
            </div>

            <div className="overview-card risk-overview">
              <span>FINANCIAL RISK</span>

              <strong>{score(member?.financialRisk)}</strong>

              <small>
                {member?.riskLevel ? member.riskLevel.toUpperCase() : "PENDING"}
              </small>
            </div>
          </div>
        </section>

        <section id="savings" className="page-section">
          <div className="section-heading section-heading-inline">
            <div>
              <span className="section-eyebrow">SAVINGS</span>

              <h2>Member Savings</h2>

              <p>
                Savings provide the foundation for cooperative credit
                participation.
              </p>
            </div>

            <div className="button-group">
              <button
                className="primary-button"
                onClick={() => setShowDepositForm(!showDepositForm)}
              >
                + Deposit
              </button>

              <button className="secondary-button">Withdraw</button>
            </div>
          </div>

          <div className="savings-layout">
            <div className="balance-card">
              <span className="card-label">AVAILABLE SAVINGS</span>

              <strong>{loading ? "—" : money(member?.savingsBalance)}</strong>

              <div className="balance-meta">
                <span>Member #1</span>

                <span>Onchain balance</span>
              </div>
            </div>

            <div className="activity-card">
              <div className="card-header">
                <div>
                  <span className="section-eyebrow">ACTIVITY</span>

                  <h3>Recent Savings Activity</h3>
                </div>
              </div>

              <div className="activity-row">
                <div className="activity-icon">↓</div>

                <div className="activity-info">
                  <strong>Savings balance</strong>

                  <span>Current indexed position</span>
                </div>

                <strong>{loading ? "—" : money(member?.savingsBalance)}</strong>
              </div>
            </div>
          </div>

          {showDepositForm && (
            <div className="inline-action-panel">
              <div>
                <span className="section-eyebrow">DEPOSIT</span>

                <h3>Add to member savings</h3>

                <p>
                  Deposit actions can be connected to the Savings contract. This
                  panel is currently the frontend interaction layer.
                </p>
              </div>

              <button
                className="secondary-button"
                onClick={() => setShowDepositForm(false)}
              >
                Close
              </button>
            </div>
          )}
        </section>

        <section id="loans" className="page-section">
          <div className="section-heading section-heading-inline">
            <div>
              <span className="section-eyebrow">CREDIT & LENDING</span>

              <h2>Loans</h2>

              <p>CreditScore → ActuarialEngine → LoanEngine → Risk Decision.</p>
            </div>

            <button
              className="primary-button"
              onClick={() => setShowLoanForm(!showLoanForm)}
            >
              + Request Loan
            </button>
          </div>

          {showLoanForm && (
            <form className="loan-form" onSubmit={submitLoanAnalysis}>
              <div className="form-field">
                <label>Requested amount</label>

                <div className="input-wrap">
                  <input
                    value={amount}
                    onChange={(event) => setAmount(event.target.value)}
                    type="number"
                    min="0.01"
                    step="0.01"
                  />

                  <span>USDC</span>
                </div>
              </div>

              <div className="form-field">
                <label>Duration</label>

                <div className="duration-display">{duration} months</div>
              </div>

              <button
                className="primary-button"
                type="submit"
                disabled={loanLoading}
              >
                {loanLoading ? "Analyzing..." : "Analyze Loan"}
              </button>
            </form>
          )}

          <div className="loan-layout">
            <div className="active-loan-card">
              <div className="card-header">
                <div>
                  <span className="section-eyebrow">ACTIVE LOAN</span>

                  <h3>Loan #1</h3>
                </div>

                {activeLoan && <span className="active-badge">ACTIVE</span>}
              </div>

              {activeLoan ? (
                <div className="loan-metrics">
                  <div>
                    <span>Principal</span>

                    <strong>{money(activeLoan.principal)}</strong>
                  </div>

                  <div>
                    <span>Amount Repaid</span>

                    <strong>{money(activeLoan.repaid)}</strong>
                  </div>

                  <div>
                    <span>Outstanding</span>

                    <strong>
                      {money(
                        Math.max(0, activeLoan.principal - activeLoan.repaid),
                      )}
                    </strong>
                  </div>

                  <div>
                    <span>Status</span>

                    <strong>ACTIVE</strong>
                  </div>
                </div>
              ) : (
                <div className="empty-state">
                  No active loan data available.
                </div>
              )}
            </div>

            <div className="decision-card">
              <div className="card-header">
                <div>
                  <span className="section-eyebrow">DETERMINISTIC ENGINE</span>

                  <h3>New Loan Request</h3>
                </div>

                {loanLoading ? (
                  <span className="loading-pill">CALCULATING</span>
                ) : (
                  <span
                    className={`decision-badge ${decisionClass(
                      loan?.decision,
                    )}`}
                  >
                    {loan?.decision?.toUpperCase() || "PENDING"}
                  </span>
                )}
              </div>

              <div className="decision-request">
                <div>
                  <span>Requested</span>

                  <strong>{money(loan?.requestedAmount)}</strong>
                </div>

                <div>
                  <span>Duration</span>

                  <strong>{loan?.durationMonths ?? duration} months</strong>
                </div>

                <div>
                  <span>Financial Risk</span>

                  <strong>{loan?.riskLevel || "—"}</strong>
                </div>
              </div>

              <div className="decision-flow">
                <span>CreditScore</span>

                <i>→</i>

                <span>ActuarialEngine</span>

                <i>→</i>

                <span>LoanEngine</span>

                <i>→</i>

                <strong>Decision</strong>
              </div>

              {loan && (
                <div className="decision-explanation">
                  {loan.reasons.length > 0 ? (
                    <>
                      <strong>Decision factors</strong>

                      <ul>
                        {loan.reasons.map((reason, index) => (
                          <li key={index}>{reason}</li>
                        ))}
                      </ul>
                    </>
                  ) : (
                    <p>
                      Decision generated from the deterministic CoopChain risk
                      engine.
                    </p>
                  )}
                </div>
              )}

              {loan && (
                <div className="decision-request">
                  <div>
                    <span>Current exposure</span>

                    <strong>{money(loan.currentLoanExposure)}</strong>
                  </div>

                  <div>
                    <span>Projected exposure</span>

                    <strong>{money(loan.projectedLoanExposure)}</strong>
                  </div>

                  <div>
                    <span>Loan / savings</span>

                    <strong>
                      {loan.projectedLoanToSavingsRatio !== undefined
                        ? `${loan.projectedLoanToSavingsRatio.toFixed(2)}x`
                        : "—"}
                    </strong>
                  </div>
                </div>
              )}
            </div>
          </div>
        </section>

        <section id="investments" className="page-section">
          <div className="section-heading">
            <div>
              <span className="section-eyebrow">TOKENIZED INVESTMENTS</span>

              <h2>Investment Registry</h2>

              <p>
                Tokenized investment opportunities available through CoopChain.
              </p>
            </div>
          </div>

          <div className="investment-layout">
            <div className="investment-product-card">
              <div className="investment-card-top">
                <span className="investment-symbol">{investmentSymbol}</span>

                <span className="connected-badge">
                  {investmentProduct?.active === false
                    ? "INACTIVE"
                    : investment
                      ? "AVAILABLE"
                      : "UNAVAILABLE"}
                </span>
              </div>

              <span className="investment-type">{investmentAssetType}</span>

              <h3>{investmentName}</h3>

              <p>
                Tokenized investment product registered through the CoopChain
                InvestmentRegistry.
              </p>

              <div className="investment-details">
                <div>
                  <span>Token</span>

                  <code>{abbreviateWallet(investmentProduct?.token)}</code>
                </div>

                <div>
                  <span>Price</span>

                  <strong>
                    {investmentProduct?.price !== undefined
                      ? money(investmentProduct.price)
                      : "—"}
                  </strong>
                </div>

                <div>
                  <span>Total Supply</span>

                  <strong>
                    {/*
                     * UPDATED:
                     * Display CCREF supply in human-readable token units.
                     */}
                    {investmentProduct?.totalSupply !== undefined
                      ? tokenSupply(investmentProduct.totalSupply)
                      : "—"}
                  </strong>
                </div>

                <div>
                  <span>Network</span>

                  <strong>Hedera</strong>
                </div>
              </div>

              <button className="primary-button full-width">Invest</button>
            </div>

            <div className="position-card">
              <div className="card-header">
                <div>
                  <span className="section-eyebrow">INVESTMENT POSITION</span>

                  <h3>
                    {investmentSymbol !== "—"
                      ? investmentSymbol
                      : "Investment Position"}
                  </h3>
                </div>

                <span
                  className={`decision-badge ${severityClass(
                    investmentRiskLevel,
                  )}`}
                >
                  {investmentRiskLevel !== "—"
                    ? `${investmentRiskLevel.toUpperCase()} RISK`
                    : "—"}
                </span>
              </div>

              <div className="position-product">
                <div className="position-product-info">
                  <strong className="position-product-name">
                    {investmentName}
                  </strong>

                  <span className="position-product-type">
                    {investmentAssetType}
                  </span>

                  <small className="position-product-description">
                    Hedera tokenized investment asset
                  </small>
                </div>
              </div>

              <div className="position-score">
                <div className="position-score-header">
                  <span>Investment Safety Score</span>

                  <strong>{score(investmentRiskScore)}</strong>
                </div>

                <div className="score-track">
                  <div
                    className="score-fill"
                    style={{
                      width: `${Math.min(
                        100,
                        Math.max(0, investmentRiskScore || 0),
                      )}%`,
                    }}
                  />
                </div>
              </div>

              <div className="position-metrics">
                <div className="position-metric">
                  <span>Net Exposure</span>
                  <strong>{money(investmentNetExposure)}</strong>
                </div>

                <div className="position-metric">
                  <span>Position</span>
                  <strong>{money(investment?.position?.amount)}</strong>
                </div>

                <div className="position-metric">
                  <span>Value</span>
                  <strong>{money(investment?.position?.value)}</strong>
                </div>
              </div>

              <div className="position-history">
                <div className="position-history-item">
                  <span>Purchases</span>
                  <strong>
                    {investmentPurchaseAmount !== undefined
                      ? money(investmentPurchaseAmount)
                      : investmentPurchases !== undefined
                        ? investmentPurchases
                        : "—"}
                  </strong>
                </div>

                <div className="position-history-item">
                  <span>Redemptions</span>
                  <strong>
                    {investmentRedemptionAmount !== undefined
                      ? money(investmentRedemptionAmount)
                      : investmentRedemptions !== undefined
                        ? investmentRedemptions
                        : "—"}
                  </strong>
                </div>

                <div className="position-history-item">
                  <span>Transactions</span>
                  <strong>
                    {investmentTransactions !== undefined
                      ? investmentTransactions
                      : "—"}
                  </strong>
                </div>
              </div>

              <div className="hedera-note">
                <span className="integration-logo">H</span>

                <div>
                  <strong>Tokenized on Hedera</strong>

                  <span>
                    Investment registry and position data are surfaced through
                    the CoopChain data layer.
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="risk" className="page-section risk-section">
          <div className="section-heading">
            <div>
              <span className="section-eyebrow">RISK & INTELLIGENCE</span>

              <h2>Financial Risk Intelligence</h2>

              <p>
                Deterministic blockchain risk analysis supported by Chainlink
                confidential workflows and AI explanations.
              </p>
            </div>
          </div>

          <div className="risk-score-grid">
            <div className="risk-score-card">
              <div>
                <span className="section-eyebrow">CREDIT SCORE</span>

                <h3>Member Credit</h3>
              </div>

              <strong>{score(member?.creditScore)}</strong>

              <div className="score-track">
                <div
                  className="score-fill"
                  style={{
                    width: `${Math.min(
                      100,
                      Math.max(0, member?.creditScore || 0),
                    )}%`,
                  }}
                />
              </div>

              <span className="risk-caption">Current onchain score</span>
            </div>

            <div className="risk-score-card">
              <div>
                <span className="section-eyebrow">FINANCIAL RISK</span>

                <h3>Member Risk</h3>
              </div>

              <strong>{score(member?.financialRisk)}</strong>

              <div className="score-track">
                <div
                  className="score-fill"
                  style={{
                    width: `${Math.min(
                      100,
                      Math.max(0, member?.financialRisk || 0),
                    )}%`,
                  }}
                />
              </div>

              <span className="risk-caption">
                {member?.riskLevel?.toUpperCase() || "PENDING"}
              </span>
            </div>

            <div className="risk-score-card">
              <div>
                <span className="section-eyebrow">LOAN DECISION</span>

                <h3>New Loan Request</h3>
              </div>

              <strong className={decisionClass(loan?.decision)}>
                {loan?.decision?.toUpperCase() || "PENDING"}
              </strong>

              <span className="risk-caption">
                Credit risk:{" "}
                {loan?.creditRiskTier || loan?.riskLevel || "Awaiting analysis"}
              </span>
            </div>
          </div>

          <div className="risk-content-grid">
            <div className="risk-drivers-card">
              <div className="card-header">
                <div>
                  <span className="section-eyebrow">
                    DETERMINISTIC ANALYSIS
                  </span>

                  <h3>Risk Drivers</h3>
                </div>
              </div>

              {member?.riskDrivers?.length ? (
                <div className="risk-driver-list">
                  {member.riskDrivers.map((driver, index) => (
                    <div className="risk-driver-card" key={index}>
                      <div className="driver-number">
                        {String(index + 1).padStart(2, "0")}
                      </div>

                      <div className="driver-content">
                        <div className="driver-title-row">
                          <strong>{driver.name}</strong>

                          <span
                            className={`severity-badge ${severityClass(
                              driver.severity,
                            )}`}
                          >
                            {driver.severity?.toUpperCase()}
                          </span>
                        </div>

                        <p>
                          {driver.description ||
                            driver.impact ||
                            "Risk factor identified by the deterministic engine."}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="empty-state">
                  Risk drivers will appear when member data is available.
                </div>
              )}
            </div>

            <div className="cre-card">
              <div className="cre-header">
                <div className="integration-logo">C</div>

                <span className={creRisk ? "connected-badge" : "loading-pill"}>
                  {creLoading
                    ? "CHECKING"
                    : creRisk
                      ? "RESULT AVAILABLE"
                      : "AWAITING EVALUATION"}
                </span>
              </div>

              <span className="section-eyebrow">CHAINLINK CRE</span>

              <h3>Confidential Risk Evaluation</h3>

              <p>
                The financial snapshot is evaluated inside the Chainlink
                confidential workflow. Only the final risk decision is returned
                to CoopChain.
              </p>

              <div className="cre-result">
                <span>Confidential risk tier</span>

                <strong className={creDecisionClass}>
                  {creRiskTier
                    ? creRiskTier.toUpperCase()
                    : creLoading
                      ? "CHECKING"
                      : "PENDING"}
                </strong>
              </div>

              <div className="cre-result">
                <span>Loan eligibility</span>

                <strong
                  className={
                    creRisk ? (creEligible ? "success" : "danger") : ""
                  }
                >
                  {creRisk
                    ? creEligible
                      ? "YES"
                      : "NO"
                    : creLoading
                      ? "CHECKING"
                      : "PENDING"}
                </strong>
              </div>

              <div className="cre-result">
                <span>Evaluation status</span>

                <strong>
                  {creRisk
                    ? "COMPLETED"
                    : creLoading
                      ? "RUNNING"
                      : "AWAITING CRE"}
                </strong>
              </div>

              <div className="cre-result">
                <span>Last evaluation</span>

                <strong>{formattedCRETime}</strong>
              </div>

              <button
                type="button"
                className="secondary-button"
                onClick={loadConfidentialRisk}
                disabled={creLoading}
              >
                {creLoading ? "Refreshing..." : "Refresh CRE Result"}
              </button>

              <div className="hedera-note">
                <span className="integration-logo">C</span>

                <div>
                  <strong>Confidential workflow</strong>

                  <span>
                    Raw financial inputs remain inside the confidential
                    evaluation. CoopChain receives only the final risk result.
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div className="what-if-card">
            <div className="card-header">
              <div>
                <span className="section-eyebrow">INTERACTIVE ANALYSIS</span>

                <h3>What-if Loan Analysis</h3>

                <p>
                  Explore how different loan sizes and terms affect the
                  deterministic risk decision.
                </p>
              </div>
            </div>

            <div className="scenario-grid">
              {scenarios.map((scenario) => {
                const id = `${scenario.amount}-${scenario.duration}`;

                const result = scenarioResults[id];

                return (
                  <button
                    key={id}
                    type="button"
                    className={`scenario ${
                      selectedScenario === id ? "selected" : ""
                    }`}
                    onClick={async () => {
                      setSelectedScenario(id);

                      setAmount(String(scenario.amount));

                      await analyzeScenario(scenario);
                    }}
                  >
                    <span>REQUEST</span>

                    <strong>{money(scenario.amount)}</strong>

                    <small>{scenario.duration} month term</small>

                    {result?.decision && (
                      <small className={decisionClass(result.decision)}>
                        {result.loading
                          ? "CALCULATING"
                          : result.decision.toUpperCase()}
                      </small>
                    )}
                  </button>
                );
              })}
            </div>

            <div className="scenario-result">
              <div>
                <span>Selected scenario</span>

                <strong>
                  {currentScenario
                    ? `${money(currentScenario.amount)} · ${
                        currentScenario.duration
                      } months`
                    : "—"}
                </strong>
              </div>

              <div>
                <span>Decision</span>

                <strong
                  className={decisionClass(currentScenarioResult?.decision)}
                >
                  {currentScenarioResult?.loading
                    ? "CALCULATING"
                    : currentScenarioResult?.decision?.toUpperCase() ||
                      "SELECT A SCENARIO"}
                </strong>
              </div>

              <div>
                <span>Risk</span>

                <strong>{currentScenarioResult?.riskLevel || "—"}</strong>
              </div>

              <div>
                <span>Projected exposure</span>

                <strong>
                  {money(currentScenarioResult?.projectedLoanExposure)}
                </strong>
              </div>

              <div>
                <span>Loan / savings</span>

                <strong>
                  {currentScenarioResult?.projectedLoanToSavingsRatio !==
                  undefined
                    ? `${currentScenarioResult.projectedLoanToSavingsRatio.toFixed(
                        2,
                      )}x`
                    : "—"}
                </strong>
              </div>

              <div className="scenario-explanation">
                <span>Model explanation</span>

                <p>
                  {currentScenarioResult?.reasons?.length
                    ? currentScenarioResult.reasons.join(" ")
                    : currentScenarioResult?.decision
                          ?.toLowerCase()
                          .includes("approve")
                      ? "This scenario falls within the current deterministic risk model's acceptable range."
                      : currentScenarioResult?.decision
                            ?.toLowerCase()
                            .includes("review")
                        ? "This scenario requires additional review because the projected financial exposure is elevated."
                        : currentScenarioResult?.decision
                              ?.toLowerCase()
                              .includes("decline")
                          ? "This scenario is outside the current deterministic risk model's acceptable range."
                          : "Select a scenario to run a live deterministic loan analysis."}
                </p>
              </div>
            </div>
          </div>

          <div className="ai-card">
            <div className="ai-header">
              <div>
                <span className="section-eyebrow">AI RISK AGENT</span>

                <h3>Financial Intelligence</h3>

                <p>
                  AI explains deterministic risk results and translates them
                  into actionable financial guidance.
                </p>
              </div>

              <button
                className="primary-button"
                onClick={runAI}
                disabled={aiLoading || !member}
              >
                {aiLoading ? "Analyzing..." : "Run AI Analysis"}
              </button>
            </div>

            {ai ? (
              <div className="ai-result">
                <div className="ai-summary">
                  <span>ANALYSIS</span>

                  <p>
                    {ai.summary ||
                      ai.explanation ||
                      "Analysis completed successfully."}
                  </p>
                </div>

                <div className="scenario-result">
                  <div>
                    <span>Decision</span>

                    <strong className={decisionClass(ai.decision)}>
                      {ai.decision?.toUpperCase() || "—"}
                    </strong>
                  </div>

                  <div>
                    <span>Credit risk</span>

                    <strong
                      className={severityClass(
                        member?.creditRiskTier || ai.riskLevel,
                      )}
                    >
                      {(
                        member?.creditRiskTier || ai.riskLevel
                      )?.toUpperCase() || "—"}
                    </strong>
                  </div>

                  <div>
                    <span>Confidence</span>

                    <strong>{ai.confidence?.toUpperCase() || "—"}</strong>
                  </div>
                </div>

                {ai.loanAnalysis && (
                  <div className="scenario-result">
                    <div>
                      <span>Requested loan</span>

                      <strong>
                        {ai.loanAnalysis.requestedAmount
                          ? `${ai.loanAnalysis.requestedAmount} USDC`
                          : "—"}
                      </strong>
                    </div>

                    <div>
                      <span>Duration</span>

                      <strong>{ai.loanAnalysis.duration ?? "—"} months</strong>
                    </div>

                    <div>
                      <span>Projected ratio</span>

                      <strong>
                        {ai.loanAnalysis.projectedLoanToSavingsRatio !==
                        undefined
                          ? `${ai.loanAnalysis.projectedLoanToSavingsRatio.toFixed(
                              2,
                            )}x`
                          : "—"}
                      </strong>
                    </div>
                  </div>
                )}

                {ai.investmentAssessment && (
                  <div className="ai-summary">
                    <span>INVESTMENT ASSESSMENT</span>

                    <p>{ai.investmentAssessment}</p>
                  </div>
                )}

                {ai.recommendations?.length ? (
                  <div className="recommendations">
                    <span>RECOMMENDATIONS</span>

                    <div className="recommendation-list">
                      {ai.recommendations.map((recommendation, index) => (
                        <div className="recommendation" key={index}>
                          <span>{String(index + 1).padStart(2, "0")}</span>

                          <p>{String(recommendation)}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : null}

                {ai.drivers?.length ? (
                  <div className="ai-drivers">
                    <span>AI RISK DRIVERS</span>

                    <div className="recommendation-list">
                      {ai.drivers.map((driver, index) => (
                        <div className="recommendation" key={index}>
                          <span>{String(index + 1).padStart(2, "0")}</span>

                          <div>
                            <strong>{driver.name}</strong>

                            <p>
                              {driver.description ||
                                driver.impact ||
                                "Risk factor identified by the analysis engine."}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : null}

                {ai.whatIfAnalysis?.length ? (
                  <div className="ai-drivers">
                    <span>AI WHAT-IF ANALYSIS</span>

                    <div className="recommendation-list">
                      {ai.whatIfAnalysis.map((scenario, index) => (
                        <div className="recommendation" key={index}>
                          <span>{String(index + 1).padStart(2, "0")}</span>

                          <div>
                            <strong>{scenario.requestedAmount} USDC</strong>

                            <p>
                              <strong>{scenario.decision}</strong>
                              {" — "}
                              {scenario.explanation}
                            </p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : null}
              </div>
            ) : (
              <div className="ai-placeholder">
                <div className="ai-placeholder-icon">AI</div>

                <div>
                  <strong>Ask the Risk Agent</strong>

                  <p>
                    Run an analysis to understand why the current loan decision
                    was reached and what could improve the member's financial
                    position.
                  </p>
                </div>
              </div>
            )}
          </div>

          <div className="action-plan-card">
            <div>
              <span className="section-eyebrow">ACTION PLAN</span>

              <h3>Improve Financial Position</h3>
            </div>

            <div className="action-plan-grid">
              <div>
                <span>01</span>

                <strong>Increase savings</strong>

                <p>
                  Build a stronger savings base relative to outstanding
                  borrowing.
                </p>
              </div>

              <div>
                <span>02</span>

                <strong>Reduce exposure</strong>

                <p>
                  Lower outstanding loan exposure before requesting additional
                  credit.
                </p>
              </div>

              <div>
                <span>03</span>

                <strong>Establish repayment history</strong>

                <p>
                  Consistent repayments can strengthen the member's credit
                  profile.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section id="network" className="page-section network-section">
          <div className="section-heading">
            <div>
              <span className="section-eyebrow">NETWORK</span>

              <h2>CoopChain Network</h2>

              <p>
                The networks and services connected to the cooperative financial
                infrastructure.
              </p>
            </div>
          </div>

          <div className="network-grid">
            {[
              [
                "A",
                "Arc Testnet",
                "USDC financial infrastructure",
                "CONNECTED",
              ],
              [
                "H",
                "Hedera Testnet",
                "Tokenized investment assets",
                "CONNECTED",
              ],
              ["G", "The Graph", "Indexed protocol data", "INDEXED"],
              [
                "C",
                "Chainlink CRE",
                "Risk workflow infrastructure",
                "CONNECTED",
              ],
            ].map(([icon, title, description, status]) => (
              <div className="network-card" key={title}>
                <span className="network-card-icon">{icon}</span>

                <div>
                  <strong>{title}</strong>

                  <span>{description}</span>
                </div>

                <small className="connected-text">{status}</small>
              </div>
            ))}
          </div>
        </section>

        <footer className="footer">
          <div>
            <strong>COOPCHAIN</strong>

            <span>Onchain cooperative financial infrastructure.</span>
          </div>

          <div className="footer-right">
            <span>ARC TESTNET</span>

            <span>·</span>

            <span>HEDERA TESTNET</span>

            <span>·</span>

            <span>THE GRAPH</span>
          </div>
        </footer>
      </main>
    </div>
  );
}
