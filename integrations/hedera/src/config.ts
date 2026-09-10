import "dotenv/config";

function required(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

export const config = {
  accountId: required("HEDERA_ACCOUNT_ID"),
  privateKey: required("HEDERA_PRIVATE_KEY"),

  rpcUrl:
    process.env.HEDERA_RPC_URL ??
    "https://testnet.hashio.io/api",

  mirrorNode:
    process.env.HEDERA_MIRROR_NODE ??
    "https://testnet.mirrornode.hedera.com/api/v1/",

  atsResolver:
    process.env.ATS_RESOLVER ??
    "0.0.7707874",

  atsFactory:
    process.env.ATS_FACTORY ??
    "0.0.7708432",
} as const;
