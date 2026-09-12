# 🏦 CoopChain

**Onchain cooperative financial infrastructure for savings, risk-based lending, and tokenized investments.**

CoopChain is a blockchain-based financial infrastructure designed for cooperatives and SACCOs. It brings cooperative savings, credit assessment, actuarial loan calculations, stablecoin lending, treasury management, tokenized investments, and onchain risk analytics into a transparent and auditable system.

The protocol combines **smart-contract-based financial workflows**, **actuarial mathematics**, **credit risk modelling**, **tokenization**, **confidential computation**, and **AI-assisted risk analysis** to help cooperatives make more informed lending and investment decisions.

---

# 🚀 What CoopChain Does

CoopChain provides a modular financial system covering the cooperative lifecycle:

```text
                         COOPCHAIN

                            │

        ┌───────────────────┼───────────────────┐
        │                   │                   │
   MEMBERSHIP           SAVINGS            GOVERNANCE
        │                   │
        └─────────────┬─────┘
                      │
                    CREDIT
                      │
             ┌────────┴────────┐
             │                 │
        CreditScore     ActuarialEngine
             │                 │
             └────────┬────────┘
                      │
                  LoanEngine
                      │
                     USDC
                      │
                Arc Treasury
                      │
             ┌────────┴────────┐
             │                 │
          LENDING        INVESTMENTS
                               │
                       InvestmentRegistry
                               │
                       InvestmentToken
                               │
                        InvestmentPool
                               │
                         Hedera CCREF
                               │
                               ▼
                       Risk & Analytics
                               │
              ┌────────────────┼────────────────┐
              │                │                │
          The Graph      Chainlink CRE       AI Agent
          financial      confidential       explanation
             data            risk
```

## Core Capabilities

* Cooperative member registration
* Savings management
* Onchain credit scoring
* Risk-based lending
* Actuarial monthly payment calculations
* Repayment schedules
* Loan default rules
* USDC treasury management
* Arc Testnet integration
* Tokenized investment products
* Hedera tokenized real-estate asset integration
* Investment portfolio positions
* Investment redemption
* Onchain financial records
* The Graph-powered financial analytics
* Confidential risk evaluation through Chainlink CRE
* AI-assisted risk explanations
* Extensive Foundry test coverage

---

# 🏗️ Architecture

CoopChain is organized into modular financial, investment, analytics, and risk components.

```text
CoopChain/

├── Membership
│   └── CoopVault.sol
│
├── Savings
│   └── Savings.sol
│
├── Credit
│   └── CreditScore.sol
│
├── Actuarial
│   └── ActuarialEngine.sol
│
├── Lending
│   └── LoanEngine.sol
│
├── Investment
│   ├── InvestmentRegistry.sol
│   ├── InvestmentToken.sol
│   └── InvestmentPool.sol
│
├── Sponsors
│   ├── Arc
│   │   ├── ArcTreasury.sol
│   │   └── interfaces/
│   │
│   └── Hedera
│       └── HederaTokenization.sol
│
├── API
│   ├── Risk Engine
│   ├── Investment Risk
│   ├── Loan Decision
│   └── AI Risk Agent
│
├── Graph
│   └── coopchain-risk
│
└── Chainlink CRE
    └── coopchain-risk
```

The architecture deliberately separates financial responsibilities.

```text
Member
  │
  ▼
Savings
  │
  ▼
CreditScore
  │
  ├───────────────┐
  ▼               ▼
LoanEngine   ActuarialEngine
  │
  ▼
Arc Treasury
  │
  ▼
USDC Lending

InvestmentRegistry
  │
  ▼
InvestmentPool
  │
  ├── InvestmentToken
  │
  └── Hedera CCREF

The Graph
  │
  ▼
Risk API
  │
  ├── Deterministic Risk Engine
  ├── Loan Decision Engine
  ├── Investment Risk Engine
  │
  └── Chainlink CRE
          │
          ▼
      Confidential
       Risk Policy
          │
          ▼
      AI Risk Agent
```

This separation keeps financial truth, financial calculations, confidential policy evaluation, and AI interpretation as distinct layers.

---

# 👥 Membership

`CoopVault` manages cooperative membership.

Members can be registered and deactivated while maintaining an onchain record of their cooperative participation.

The membership layer acts as an identity and eligibility layer for the rest of the cooperative financial system.

---

# 💰 Savings

`Savings.sol` manages member savings using an ERC-20 compatible stablecoin.

Savings provide the financial foundation for the credit system.

The savings layer is also used by the credit scoring system to evaluate member financial behaviour.

---

# 📊 Credit Scoring

`CreditScore.sol` calculates a member's cooperative credit score.

The current V1 model combines:

```text
Credit Score

│
├── Membership Score       30%
│
└── Savings Behaviour      70%
```

The model considers factors such as:

* Membership duration
* Savings balance
* Deposit behaviour
* Savings discipline

The resulting score determines a member's risk tier.

## Risk-Based Lending

Loan decisions use the member's risk tier to determine the applicable interest rate.

| Risk Tier | Interest Rate |
| --------- | ------------: |
| Very Low  |            5% |
| Low       |            7% |
| Medium    |           10% |
| High      |           15% |
| Very High |      Rejected |

The credit model is intentionally modular so additional repayment history and behavioural signals can be incorporated in future versions.

---

# 🧮 Actuarial Loan Calculations

`ActuarialEngine.sol` provides the mathematical layer for CoopChain's lending system.

It supports:

* Simple interest
* Compound interest
* Future value
* Present value
* Monthly loan payments

Monthly payments are calculated using an **annuity-immediate** approach with fixed-point precision.

Conceptually:

```text
Loan Principal
      │
      ▼
Interest Rate
      │
      ▼
Loan Duration
      │
      ▼
ActuarialEngine
      │
      ▼
Monthly Payment
```

This separates financial mathematics from the loan lifecycle itself.

---

# 🏦 LoanEngine

`LoanEngine.sol` coordinates the cooperative lending workflow.

## Loan Lifecycle

```text
Pending
   │
   ▼
Active
   │
   ├──────────────► Repaid
   │
   └──────────────► Defaulted

Pending ──────────► Cancelled
```

The engine:

1. Validates cooperative membership
2. Evaluates savings and credit information
3. Determines the applicable risk tier
4. Applies the corresponding interest rate
5. Calculates the actuarial monthly payment
6. Disburses the loan
7. Tracks repayment progress
8. Advances the next repayment date
9. Detects eligible defaults

## Repayment Schedule

Loan schedules are derived from:

* Principal
* Interest rate
* Loan duration
* Monthly payment
* Repayment interval

The current repayment interval is **30 days**.

A loan becomes eligible for default after:

```text
Next Due Date + 7-day Grace Period
```

The implementation keeps the core loan workflow modular without storing an unnecessary array of every future installment.

---

# 💵 Arc Treasury Integration

CoopChain integrates with **Arc Testnet** for USDC treasury management and lending liquidity.

The architecture separates the lending engine from custody of the cooperative's USDC liquidity.

```text
                    Arc Testnet
                         │
                        USDC
                         │
                         ▼
                 ┌─────────────┐
                 │ ArcTreasury │
                 └──────┬──────┘
                        │
                 Authorized
                  LoanEngine
                        │
                        ▼
                    Borrower
```

## Why the Treasury Layer?

Instead of allowing `LoanEngine` to permanently hold cooperative liquidity, `ArcTreasury` provides a dedicated treasury layer.

The treasury controls:

* Funding
* Authorized loan disbursement
* Treasury withdrawals
* Operator permissions
* Liquidity checks

Only authorized operators can release funds for lending.

## Arc Testnet

CoopChain has been deployed and tested against the Arc Testnet USDC environment.

```text
Network:
Arc Testnet

Chain ID:
5042002

USDC:
0x3600000000000000000000000000000000000000

ArcTreasury:
0xA65e8F2B43687bBdc3739B7268eA355c2cf55701
```

> ⚠️ **Testnet deployment only. Do not use these addresses for production funds.**

---

# 📈 Tokenized Investments

CoopChain provides an investment infrastructure layer for cooperative members.

```text
InvestmentRegistry
        │
        ▼
InvestmentToken
        │
        ▼
InvestmentPool
        │
        ├──────────────► Hedera CCREF
        │
        ▼
       USDC
```

## InvestmentRegistry

`InvestmentRegistry.sol` maintains investment product metadata.

Supported asset categories include:

* Equity
* Bonds
* Funds
* Real Estate
* Receivables

Each registered investment contains information such as:

* Name
* Symbol
* Asset type
* Issuer
* Token address
* Price
* Supply
* Active status

---

# 🪙 InvestmentToken

`InvestmentToken.sol` represents a member's position in an investment product.

Tokens are:

* ERC-20 compatible
* Associated with a registered investment
* Minted by the authorized investment pool
* Burned during redemption
* Subject to a maximum supply

---

# 🏊 InvestmentPool

`InvestmentPool.sol` manages the capital flow between members and investment products.

## Investment

```text
Member
  │
  │ USDC
  ▼
InvestmentPool
  │
  ├── Validate investment
  ├── Read price
  ├── Calculate units
  ├── Transfer USDC
  └── Mint InvestmentToken
```

## Redemption

```text
Member
  │
  │ InvestmentToken
  ▼
InvestmentPool
  │
  ├── Calculate redemption value
  ├── Burn tokens
  └── Transfer USDC
```

Investment prices can change, allowing the value of a member's position to change accordingly.

> **Important:** Investment tokens represent rights defined by the corresponding investment product. They should not be interpreted as legal ownership of an underlying regulated security unless the relevant legal and regulatory structure supports that ownership.

---

# 🏢 Hedera Tokenization Integration

CoopChain integrates **Hedera Asset Tokenization Studio (ATS)** to demonstrate tokenized investment infrastructure.

The integration connects CoopChain's investment registry with a tokenized real-estate investment asset issued on Hedera Testnet.

## CCREF

The demonstration investment is:

```text
Name:
CoopChain Real Estate Fund

Symbol:
CCREF

Asset Type:
REAL_ESTATE

Maximum Supply:
1,000,000

Decimals:
18

Currency:
USD

Whitelist:
Enabled

Internal KYC:
Enabled

ISIN:
KE0000000091
```

The issued Hedera security has:

```text
Security EVM Address:
0x92EFe5B72783352675Ce84B65604e87ceE6b44C9

Hedera Contract ID:
0.0.10454483
```

The issuance transaction:

```text
0x57c3e7bc4285102f79a0706c3d92d704d78c6dd9cd16a9d5b55455c5208e648c
```

The asset was successfully issued on Hedera Testnet after validating the ISIN checksum.

CoopChain uses the Hedera asset as the tokenized investment product represented by its investment infrastructure.

---

# 📊 The Graph — Onchain Financial Data

CoopChain integrates **The Graph** to provide indexed, queryable financial data for its risk infrastructure.

The CoopChain subgraph indexes key financial events and entities from the Arc Testnet deployment.

The indexed data includes:

* Cooperative members
* Savings activity
* Loans
* Loan repayments
* Investment products
* Investment positions
* Investment token activity
* Investment pool activity

The Risk API consumes this indexed data rather than reconstructing the entire financial state directly from individual blockchain calls.

```text
Arc Testnet
     │
     ▼
CoopChain Contracts
     │
     ▼
The Graph Subgraph
     │
     ▼
Financial Data
     │
     ▼
CoopChain Risk API
```

This makes The Graph a **load-bearing component** of CoopChain's risk architecture.

The indexed financial state is then used by:

* Member risk analysis
* Loan decision evaluation
* Investment risk analysis
* AI Risk Agent
* Chainlink confidential risk evaluation

---

# 🔐 Chainlink CRE — Confidential Risk Workflow

CoopChain integrates **Chainlink CRE (Compute Runtime Environment)** to add a confidential risk-policy evaluation layer to its lending infrastructure.

The purpose of this integration is to evaluate sensitive risk-policy logic inside a **Trusted Execution Environment (TEE)**.

The confidential workflow uses `handlerInTee` and targets an **AWS Nitro TEE**.

## Architecture

```text
                    The Graph
                        │
                        ▼
                CoopChain Risk API
                        │
                 Financial Snapshot
                        │
            ┌───────────┴───────────┐
            │                       │
            ▼                       ▼
   Deterministic Risk        Chainlink CRE
        Engine                    │
            │                      ▼
            │                AWS Nitro TEE
            │                      │
            │                Private Risk
            │                   Policy
            │                      │
            │                      ▼
            │               Risk Classification
            │                      │
            └───────────┬──────────┘
                        ▼
                  AI Risk Agent
```

## How the Confidential Workflow Works

1. The Graph provides CoopChain's indexed financial data.
2. The CoopChain Risk API provides the financial snapshot required for evaluation.
3. Chainlink CRE receives the financial data through its HTTP capability.
4. The confidential handler executes inside the TEE.
5. Private risk-policy parameters are evaluated inside the TEE.
6. The workflow returns only a high-level risk classification and eligibility result.
7. The AI Risk Agent can explain the resulting risk assessment.

The private policy parameters are intentionally not exposed by the workflow output.

The workflow evaluates factors including:

* Credit score
* Loan-to-savings ratio
* Repayment history

The result is reduced to a high-level classification such as:

```json
{
  "eligible": false,
  "riskTier": "HIGH"
}
```

## Why Chainlink CRE?

Chainlink CRE does **not** replace CoopChain's deterministic risk engine.

Instead, it provides a confidential policy layer alongside the existing risk system.

```text
The Graph
    │
    ├──────────────► Deterministic Risk Engine
    │                         │
    │                         ▼
    │                    Loan Decision
    │
    └──────────────► Chainlink CRE
                              │
                              ▼
                       Confidential
                       Risk Policy
                              │
                              ▼
                       Risk Classification
                              │
                              ▼
                        AI Risk Agent
```

This architecture allows CoopChain to combine transparent financial calculations with confidential policy evaluation.

## CRE Simulation

The workflow is configured for simulation through the Chainlink CRE CLI.

The simulation requests execution in an AWS Nitro TEE and verifies the confidential workflow path:

```text
✓ Workflow compiled
✓ TEE execution requested
✓ AWS Nitro execution target
✓ Risk API request
✓ Confidential risk evaluation
✓ Risk result returned
✓ Simulation complete
```

Example result:

```text
[USER LOG] Confidential CoopChain risk evaluation: HIGH

Workflow Simulation Result:

{
  "eligible": false,
  "riskTier": "HIGH"
}
```

The intended confidential workflow path is:

```text
CoopChain Financial Data
        ↓
Risk API
        ↓
Chainlink CRE
        ↓
AWS Nitro TEE
        ↓
Confidential Policy
        ↓
Risk Result
```

---

# 🤖 AI Risk Agent

CoopChain includes an AI-powered risk analysis layer that explains deterministic financial risk results in human-readable language.

The AI agent does **not** replace the deterministic risk engine.

Instead, it receives verified outputs from:

* The Graph
* `CreditScore.sol`
* CoopChain Risk Engine
* Loan Decision Engine
* Investment Risk Engine
* Chainlink confidential risk evaluation

The agent can explain:

* Why a loan was approved, reviewed, or declined
* Credit and financial risk factors
* Savings-to-debt relationships
* Investment exposure
* What-if loan scenarios
* Recommended actions

The architecture separates **decision logic** from **AI explanation**.

```text
Verified Financial Data
        │
        ▼
Deterministic Risk Engines
        │
        ├── Loan Decision
        ├── Financial Risk
        └── Investment Risk
        │
        ▼
Chainlink Confidential Risk
        │
        ▼
AI Risk Agent
        │
        ▼
Human-readable explanation
```

The AI agent is therefore an explanation and decision-support layer rather than the authoritative source of financial truth.

---

# 🧠 Risk Engine

CoopChain's Risk API combines multiple sources of financial information into a unified risk view.

## Member Risk

The member risk engine evaluates:

* Credit score
* Savings balance
* Active loans
* Total borrowing
* Total repayments
* Repayment rate
* Loan-to-savings ratio
* Investment activity
* Net investment exposure

## Loan Decision Engine

The loan decision engine evaluates requested borrowing against the member's current financial position.

It considers:

* Credit score
* Existing loan exposure
* Savings
* Projected loan-to-savings ratio
* Repayment history
* Number of active loans

The engine returns:

```text
APPROVE
REVIEW
DECLINE
```

## Investment Risk Engine

The investment risk engine evaluates:

* Investment purchases
* Investment redemptions
* Net investment exposure
* Transaction activity
* Concentration indicators

This produces a separate investment-risk assessment that can be combined with overall financial risk.

---

# 🔎 Risk Data Flow

The complete risk architecture is:

```text
                     Blockchain
                         │
                         ▼
                    Arc Testnet
                         │
                         ▼
                   The Graph
                         │
                         ▼
                 CoopChain Risk API
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
      Member Risk    Loan Decision   Investment
        Engine          Engine        Risk Engine
          │              │              │
          └──────────────┼──────────────┘
                         │
                         ▼
                  Chainlink CRE
                         │
                         ▼
                  Confidential TEE
                         │
                         ▼
                   Risk Result
                         │
                         ▼
                   AI Risk Agent
                         │
                         ▼
                 User Explanation
```

This architecture keeps financial truth onchain and indexed while separating deterministic calculations, confidential policy evaluation, and AI explanation.

---

# 🔐 Security & Testing

CoopChain is developed using **Foundry** with extensive unit, integration, and end-to-end testing.

## Latest Full Test Suite

```text
449 tests passed
0 failed
0 skipped
13 test suites
```

Test coverage includes:

* Actuarial calculations
* Credit scoring
* Membership
* Savings
* Loan lifecycle
* Loan repayment schedules
* Loan defaults
* Arc Treasury
* Arc loan disbursement
* Investment Registry
* Investment Token
* Investment Pool
* Hedera integration
* End-to-end investment integration

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Run LoanEngine Tests

```bash
forge test --match-path "test/unit/LoanEngineTest.t.sol" -vv
```

## Run Arc Treasury Tests

```bash
forge test --match-path "test/unit/Arc/ArcTreasury.t.sol" -vv
```

## Run Integration Tests

```bash
forge test --match-path "test/integration/**" -vv
```

## Format

```bash
forge fmt
```

## Gas Snapshots

```bash
forge snapshot
```

---

# 🛠️ Technology Stack

## Smart Contracts

* Solidity
* Foundry
* Forge
* Cast
* OpenZeppelin Contracts
* ERC-20

## Blockchain

* Ethereum-compatible EVM networks
* Arc Testnet
* Hedera Testnet

## Financial Engineering

* Actuarial mathematics
* Credit risk modelling
* Fixed-point financial calculations
* Risk-tiered lending
* Loan amortization
* Investment exposure analysis

## Backend & Risk

* Node.js
* TypeScript
* Express
* Ethers.js
* The Graph
* OpenAI
* Chainlink CRE

---

# 🤝 Sponsor Integrations

CoopChain uses multiple Web3 infrastructure ecosystems as **functional components of the protocol rather than isolated demonstrations**.

| Ecosystem     | Integration                      | Role                                       |
| ------------- | -------------------------------- | ------------------------------------------ |
| **Arc**       | Arc Testnet + USDC + ArcTreasury | Cooperative treasury and lending liquidity |
| **Hedera**    | Asset Tokenization Studio        | Tokenized CCREF real-estate investment     |
| **The Graph** | CoopChain subgraph               | Indexed financial data and risk analytics  |
| **Chainlink** | CRE Confidential Workflow        | Confidential risk-policy evaluation in TEE |

## Arc

Arc provides the testnet environment and USDC infrastructure used by CoopChain's treasury and lending layer.

**Role:** liquidity, treasury management, and loan settlement.

## Hedera

Hedera provides the tokenization infrastructure used to issue the CCREF real-estate investment asset.

**Role:** tokenized investment infrastructure.

## The Graph

The Graph indexes CoopChain's onchain financial state and provides the data layer consumed by the Risk API and AI Risk Agent.

**Role:** onchain financial analytics and risk data.

## Chainlink

Chainlink CRE provides the confidential computation layer used to evaluate a private risk policy inside an AWS Nitro TEE.

**Role:** confidential risk-policy evaluation.

---

# 🌐 Arc Testnet

Arc Testnet configuration:

```text
RPC:
https://rpc.testnet.arc.network

Chain ID:
5042002

Explorer:
https://testnet.arcscan.app
```

The Arc Testnet uses USDC as its gas currency.

For local development, store sensitive configuration in `.env`.

Example:

```env
ARC_TESTNET_RPC_URL="https://rpc.testnet.arc.network"

PRIVATE_KEY="your_private_key"
```

> ⚠️ **Never commit `.env` files or private keys to GitHub.**

---

# 🚀 Deployment

Example Foundry deployment:

```bash
forge script script/Arc/DeployArcTreasury.s.sol:DeployArcTreasury \
  --rpc-url "$ARC_TESTNET_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast
```

Always verify the target network and contract configuration before broadcasting a transaction.

---

# 📁 Project Structure

```text
CoopChain/

├── api/
│   ├── src/
│   │   ├── aiRiskAgent.ts
│   │   ├── creditScore.ts
│   │   ├── format.ts
│   │   ├── graph.ts
│   │   ├── index.ts
│   │   ├── investmentRisk.ts
│   │   ├── loanDecision.ts
│   │   └── risk.ts
│   ├── package.json
│   ├── package-lock.json
│   └── tsconfig.json
│
├── coopchain-risk/
│   ├── coopchain-risk/
│   │   ├── main.ts
│   │   ├── main.test.ts
│   │   ├── workflow.yaml
│   │   ├── config.staging.json
│   │   ├── config.production.json
│   │   ├── package.json
│   │   ├── bun.lock
│   │   └── tsconfig.json
│   ├── project.yaml
│   └── secrets.yaml
│
├── graph/
│   └── coopchain-risk/
│       ├── abis/
│       │   ├── ActuarialEngine.json
│       │   ├── CoopVault.json
│       │   ├── CreditScore.json
│       │   ├── InvestmentPool.json
│       │   ├── InvestmentRegistry.json
│       │   ├── InvestmentToken.json
│       │   ├── LoanEngine.json
│       │   └── Savings.json
│       ├── src/
│       │   └── mapping.ts
│       ├── schema.graphql
│       ├── subgraph.yaml
│       ├── package.json
│       └── package-lock.json
│
├── integrations/
│   └── hedera/
│       ├── src/
│       │   ├── ats-client.ts
│       │   ├── config.ts
│       │   ├── inspect-ccref.ts
│       │   ├── issue-ccref.ts
│       │   └── test-connection.ts
│       ├── package.json
│       ├── package-lock.json
│       ├── tsconfig.json
│       └── hashgraph-asset-tokenization-contracts-4.2.0.tgz
│
├── src/
│   ├── ActuarialEngine.sol
│   ├── CoopVault.sol
│   ├── CreditScore.sol
│   ├── LoanEngine.sol
│   ├── Savings.sol
│   │
│   ├── Investment/
│   │   ├── InvestmentPool.sol
│   │   ├── InvestmentRegistry.sol
│   │   └── InvestmentToken.sol
│   │
│   ├── interfaces/
│   │   ├── IActuarialEngine.sol
│   │   ├── ICoopVault.sol
│   │   ├── ICreditScore.sol
│   │   ├── IInvestmentPool.sol
│   │   ├── IInvestmentRegistry.sol
│   │   ├── IInvestmentToken.sol
│   │   ├── ILoanEngine.sol
│   │   └── ISavings.sol
│   │
│   └── sponsors/
│       ├── Arc/
│       │   ├── ArcTreasury.sol
│       │   └── interfaces/
│       │
│       └── Hedera/
│           ├── HederaTokenization.sol
│           └── interfaces/
│
├── script/
│   ├── Arc/
│   │   ├── DeployArcTreasury.s.sol
│   │   ├── DeployCoopChain.s.sol
│   │   └── DeployInvestments.s.sol
│   └── Hedera/
│
├── test/
│   ├── unit/
│   │   ├── ActuarialEngine.t.sol
│   │   ├── CoopVault.t.sol
│   │   ├── CreditScore.t.sol
│   │   ├── InvestmentPool.t.sol
│   │   ├── InvestmentRegistry.t.sol
│   │   ├── InvestmentToken.t.sol
│   │   ├── LoanEngineTest.t.sol
│   │   ├── Savings.t.sol
│   │   │
│   │   ├── Arc/
│   │   │   └── ArcTreasury.t.sol
│   │   │
│   │   └── Hedera/
│   │       └── HederaTokenization.t.sol
│   │
│   ├── integration/
│   │   ├── InvestmentIntegration.t.sol
│   │   ├── Arc/
│   │   │   └── LoanEngineTreasury.t.sol
│   │   └── Hedera/
│   │       └── HederaInvestmentIntegration.t.sol
│   │
│   ├── mock/
│   │   └── MockUSDC.sol
│   │
│   └── libraries/
│       └── MathHelper.sol
│
├── foundry.toml
├── foundry.lock
└── README.md
```

---

# ⚙️ Getting Started

## Requirements

Install:

* Git
* Foundry
* Node.js
* Bun
* An EVM-compatible wallet

Verify Foundry:

```bash
forge --version
```

Verify Node:

```bash
node --version
```

---

## Clone

```bash
git clone git@github.com:max-wire/CoopChain.git
cd CoopChain
```

Checkout the ETHOnline development branch:

```bash
git checkout ethonline-2026
```

---

## Install Smart Contract Dependencies

If dependencies have not already been installed:

```bash
forge install
```

---

## Build

```bash
forge build
```

---

## Test

```bash
forge test
```

---

# 🔬 Risk API

The CoopChain Risk API provides a backend interface over the indexed financial data and deterministic risk engines.

The API combines:

```text
The Graph
    │
    ▼
Financial Data
    │
    ├── Member Risk
    ├── Loan Decision
    ├── Investment Risk
    └── AI Risk Agent
```

The API also connects to the Arc Testnet `CreditScore` contract for onchain credit information.

The development API runs on:

```text
http://localhost:4000
```

## Member Risk

```text
GET /api/risk/member/:wallet
```

## Loan Decision

```text
POST /api/loan/decision
```

## Investment Risk

```text
GET /api/risk/investment/:wallet
```

## AI Risk Agent

```text
POST /api/agent/analyze
```

---

# 🔗 Chainlink CRE Development

The confidential workflow is located in:

```text
coopchain-risk/

└── coopchain-risk/
    ├── main.ts
    ├── config.staging.json
    ├── config.production.json
    └── workflow.yaml
```

Install workflow dependencies:

```bash
cd coopchain-risk/coopchain-risk
bun install
```

Typecheck:

```bash
npm run typecheck
```

Run the CRE simulation from the project root:

```bash
cd ~/Blockchain/CoopChain/coopchain-risk

cre workflow simulate coopchain-risk --target staging-settings
```

The workflow requires access to the Risk API during simulation.

For local development, the Risk API can be exposed through a temporary HTTPS tunnel.

> **Note:** The CRE workflow is configured to execute the confidential risk handler using an AWS Nitro TEE target.

---

# 🧪 Development Philosophy

CoopChain follows a modular architecture where financial responsibilities are separated between contracts and infrastructure services.

```text
Identity
   │
   ▼
Savings
   │
   ▼
Credit Risk
   │
   ▼
Actuarial Mathematics
   │
   ▼
Loan Lifecycle
   │
   ▼
Treasury
   │
   ▼
Investments
   │
   ▼
Financial Analytics
   │
   ▼
Confidential Risk
   │
   ▼
AI Explanation
```

This separation makes the system easier to:

* Test
* Audit
* Extend
* Integrate with external protocols
* Replace individual financial models
* Add new risk models
* Add new investment products
* Maintain clear boundaries between financial truth and AI interpretation

---

# 🧭 Future Direction

Future versions of CoopChain can extend the current architecture with:

* Historical repayment-based credit scoring
* More sophisticated debt-to-savings analysis
* Automated repayment processing
* Additional confidential risk policies
* Advanced AI-assisted credit risk analysis
* Chainlink-powered automation
* Additional Hedera tokenized assets
* ENS-based cooperative/member identities
* Human verification
* Multi-chain cooperative treasury infrastructure
* Governance-driven investment decisions
* Additional investment products
* Multi-asset cooperative portfolios

The long-term goal is to create an **onchain financial operating system for cooperatives and SACCOs**.

---

# 🏆 ETHOnline 2026

CoopChain is being developed for **ETHOnline 2026**.

The project combines:

**Cooperative Finance + DeFi + Actuarial Science + Tokenization + Onchain Risk Management + Confidential Computing + AI**

The current implementation demonstrates functional integrations with:

* **Arc** — USDC treasury and lending
* **Hedera** — tokenized real-estate investment infrastructure
* **The Graph** — indexed financial data and risk analytics
* **Chainlink CRE** — confidential risk-policy evaluation

The project architecture is designed around a simple principle:

> **Financial truth should be verifiable, risk decisions should be systematic, sensitive policies can remain confidential, and AI should explain rather than invent the decision.**

---

# 📜 License

MIT License.
