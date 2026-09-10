import {
  Network,
  InitializationRequest,
  ConnectRequest,
  SupportedWallets,
} from "@hashgraph/asset-tokenization-sdk";

import { config } from "./config.js";

const mirrorNode = {
  baseUrl: config.mirrorNode,
};

const rpcNode = {
  baseUrl: config.rpcUrl,
};

async function main() {
  console.log("Initializing Asset Tokenization Studio...");
  console.log(`Account: ${config.accountId}`);

  await Network.init(
    new InitializationRequest({
      network: "testnet",
      mirrorNode: mirrorNode as any,
      rpcNode: rpcNode as any,
    }),
  );

  console.log("ATS network initialized.");

  const result = await Network.connect(
    new ConnectRequest({
      account: {
        accountId: config.accountId,
        privateKey: {
          key: config.privateKey,
          type: "ECDSA",
        },
      },
      network: "testnet",
      mirrorNode: mirrorNode as any,
      rpcNode: rpcNode as any,
      wallet: SupportedWallets.METAMASK,
    }),
  );

  console.log("ATS connected successfully!");
  console.log(result);
}

main().catch((error) => {
  console.error("ATS connection failed:");
  console.error(error);
  process.exit(1);
});