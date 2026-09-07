# 🏦 CoopChain

**Onchain cooperative financial infrastructure for savings, risk-based lending, and tokenized investments.**

CoopChain is a blockchain-based financial infrastructure designed for cooperatives and SACCOs. It brings cooperative savings, credit assessment, actuarial loan calculations, stablecoin lending, treasury management, and investment opportunities into a transparent and auditable onchain system.

The protocol combines **smart-contract-based financial workflows** with **risk modelling and actuarial mathematics** to help cooperatives make more informed lending and investment decisions.

---

## 🚀 What CoopChain Does

CoopChain provides a modular financial system covering the cooperative lifecycle:

```text
                         COOPCHAIN
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   MEMBERSHIP            SAVINGS            GOVERNANCE
        │                   │
        └─────────────┬─────┘
                      │
                    CREDIT
                      │
             ┌────────┴────────┐
             │                 │
        CreditScore      ActuarialEngine
             │                 │
             └────────┬────────┘
                      │
                  LoanEngine
                      │
                    USDC
                      │
                 Arc Treasury
                      │
              ┌───────┴────────┐
              │                │
           LENDING        INVESTMENTS
                               │
                       InvestmentRegistry
                               │
                       InvestmentToken
                               │
                        InvestmentPool
```

### Core Capabilities

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
* Investment portfolio positions
* Investment redemption
* Onchain financial records
* Extensive Foundry test coverage

---

# 🏗️ Architecture

CoopChain is organized into modular components.

```text
src/
├── CoopVault.sol
├── Savings.sol
├── CreditScore.sol
├── LoanEngine.sol
├── ActuarialEngine.sol
│
├── Investment/
│   ├── InvestmentRegistry.sol
│   ├── InvestmentToken.sol
│   └── InvestmentPool.sol
│
└── sponsors/
    └── Arc/
        ├── ArcTreasury.sol
        └── interfaces/
            └── IArcTreasury.sol
```

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

The current lending model supports:

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

CoopChain integrates with **Arc Testnet** for USDC treasury management.

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

CoopChain has been tested against the Arc Testnet USDC environment.

```text
Network: Arc Testnet
Chain ID: 5042002
USDC: 0x3600000000000000000000000000000000000000
```

The deployed test treasury is:

```text
0xA65e8F2B43687bBdc3739B7268eA355c2cf55701
```

> ⚠️ **Testnet deployment only. Do not use these addresses for production funds.**

---

# 📈 Tokenized Investments

CoopChain also provides an investment infrastructure layer.

```text
InvestmentRegistry
        │
        ▼
InvestmentToken
        │
        ▼
InvestmentPool
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

## InvestmentToken

`InvestmentToken.sol` represents a member's position in an investment product.

Tokens are:

* ERC-20 compatible
* Associated with a registered investment
* Minted by the authorized investment pool
* Burned during redemption
* Subject to a maximum supply

---

## InvestmentPool

`InvestmentPool.sol` manages the capital flow between members and investment products.

### Investment

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

### Redemption

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

# 🔐 Security & Testing

CoopChain is developed using **Foundry** with extensive unit and integration testing.

### Latest Full Test Suite

```text
433 tests passed
0 failed
0 skipped
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

## Financial Engineering

* Actuarial mathematics
* Credit risk modelling
* Fixed-point financial calculations
* Risk-tiered lending

## Planned / Targeted Integrations

CoopChain is being developed with additional Web3 infrastructure integrations in mind:

| Technology | Intended Role                        |
| ---------- | ------------------------------------ |
| Arc        | USDC treasury and settlement         |
| Hedera     | Tokenized investment infrastructure  |
| The Graph  | Onchain financial analytics          |
| Chainlink  | Trusted external data and automation |
| ENS        | Human-readable identities            |
| World      | Human/member verification            |

> **Note:** Only integrations explicitly implemented in the codebase should be considered production features.

---

# 📁 Project Structure

```text
CoopChain/
│
├── src/
│   ├── CoopVault.sol
│   ├── Savings.sol
│   ├── CreditScore.sol
│   ├── LoanEngine.sol
│   ├── ActuarialEngine.sol
│   │
│   ├── Investment/
│   │   ├── InvestmentRegistry.sol
│   │   ├── InvestmentToken.sol
│   │   └── InvestmentPool.sol
│   │
│   └── sponsors/
│       └── Arc/
│           ├── ArcTreasury.sol
│           └── interfaces/
│
├── test/
│   ├── unit/
│   ├── integration/
│   ├── mock/
│   └── libraries/
│
├── script/
│   └── Arc/
│       └── DeployArcTreasury.s.sol
│
├── foundry.toml
├── .gitignore
└── README.md
```

---

# ⚙️ Getting Started

## Requirements

Install:

* Git
* Foundry
* An EVM-compatible wallet

Verify Foundry:

```bash
forge --version
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

## Install Dependencies

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

> ⚠️ **Never commit `.env` or private keys to GitHub.**

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

# 🧪 Development Philosophy

CoopChain follows a modular architecture where financial responsibilities are separated between contracts.

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
```

This separation makes the system easier to:

* Test
* Audit
* Extend
* Integrate with external protocols
* Replace individual financial models without redesigning the entire lending workflow

---

# 🧠 Future Direction

Future versions of CoopChain can extend the current architecture with:

* Historical repayment-based credit scoring
* More sophisticated debt-to-savings analysis
* AI-assisted credit risk analysis
* Automated repayment processing
* Chainlink-powered automation
* Onchain analytics through The Graph
* Hedera-based tokenized assets
* ENS-based cooperative/member identities
* Human verification
* Multi-chain cooperative treasury infrastructure
* Governance-driven investment decisions
* Additional investment products

The long-term goal is to create an **onchain financial operating system for cooperatives and SACCOs**.

---

# 🏆 ETHOnline 2026

CoopChain is being developed for **ETHOnline 2026**.

The project focuses on combining:

**Cooperative Finance + DeFi + Actuarial Science + Tokenization + Onchain Risk Management**

The project targets sponsor ecosystems including:

* Arc
* Hedera
* The Graph
* Chainlink
* ENS
* World

---

# 📜 License

MIT License.
