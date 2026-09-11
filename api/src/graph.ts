const GRAPH_URL = process.env.GRAPH_URL!;

async function queryGraph<T>(
  query: string,
  variables: Record<string, unknown> = {}
): Promise<T> {
  const response = await fetch(GRAPH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query,
      variables,
    }),
  });

  if (!response.ok) {
    throw new Error(`Graph request failed: ${response.status}`);
  }

  const body = await response.json();

  if (body.errors) {
    throw new Error(JSON.stringify(body.errors));
  }

  return body.data;
}

export interface Member {
  id: string;
  memberId: string;
  wallet: string;
  joinedAt: string;
  active: boolean;
  savingsBalance: string;
}

export interface Loan {
  id: string;
  loanId: string;
  borrower: string;
  principal: string;
  interestRateBps: string;
  duration: string;
  monthlyPayment: string;
  totalRepayment: string;
  amountRepaid: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface InvestmentTransaction {
  id: string;
  investor: string;
  usdcAmount: string;
  tokenAmount: string;
  type: string;
  timestamp: string;
  transactionHash: string;
}

export interface SavingsTransaction {
  id: string;
  user: string;
  amount: string;
  newBalance: string;
  type: string;
  timestamp: string;
  transactionHash: string;
}

export async function getMemberFinancialData(wallet: string) {
  const data = await queryGraph<{
    members: Member[];
    loans: Loan[];
    investmentTransactions: InvestmentTransaction[];
    savingsTransactions: SavingsTransaction[];
  }>(
    `
      query MemberRiskData($wallet: Bytes!) {
        members(
          where: { wallet: $wallet }
          first: 1
        ) {
          id
          memberId
          wallet
          joinedAt
          active
          savingsBalance
        }

        loans(
          where: { borrower: $wallet }
          first: 100
        ) {
          id
          loanId
          borrower
          principal
          interestRateBps
          duration
          monthlyPayment
          totalRepayment
          amountRepaid
          status
          createdAt
          updatedAt
        }

        investmentTransactions(
          where: { investor: $wallet }
          first: 100
        ) {
          id
          investor
          usdcAmount
          tokenAmount
          type
          timestamp
          transactionHash
        }

        savingsTransactions(
          where: { user: $wallet }
          first: 100
        ) {
          id
          user
          amount
          newBalance
          type
          timestamp
          transactionHash
        }
      }
    `,
    {
      wallet: wallet.toLowerCase(),
    }
  );

  return data;
}