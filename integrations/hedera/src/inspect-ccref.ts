import { ethers } from "ethers";
import "dotenv/config";

import { config } from "./config.js";

const TX_HASH =
  "0x57c3e7bc4285102f79a0706c3d92d704d78c6dd9cd16a9d5b55455c5208e648c";

async function main() {
  console.log("==============================================");
  console.log("CoopChain — Inspect Existing CCREF Issuance");
  console.log("==============================================");

  const provider = new ethers.JsonRpcProvider(config.rpcUrl);

  const network = await provider.getNetwork();

  console.log(`Chain ID: ${network.chainId}`);

  if (network.chainId !== 296n) {
    throw new Error(
      `Wrong network. Expected Hedera Testnet chain ID 296, got ${network.chainId}`,
    );
  }

  console.log("");
  console.log("Reading existing transaction...");
  console.log(`Transaction: ${TX_HASH}`);

  const tx = await provider.getTransaction(TX_HASH);

  if (!tx) {
    throw new Error(`Transaction not found: ${TX_HASH}`);
  }

  console.log(`From: ${tx.from}`);
  console.log(`To:   ${tx.to}`);
  console.log(`Data: ${tx.data.slice(0, 10)}...`);

  console.log("");
  console.log("Waiting for existing transaction receipt...");

  const receipt = await provider.getTransactionReceipt(TX_HASH);

  if (!receipt) {
    throw new Error(`Transaction receipt not found: ${TX_HASH}`);
  }

  console.log(`Block:  ${receipt.blockNumber}`);
  console.log(`Status: ${receipt.status}`);

  console.log("");
  console.log("==============================================");
  console.log("Transaction logs");
  console.log("==============================================");

  if (receipt.logs.length === 0) {
    console.log("No logs were emitted.");
  } else {
    for (const [index, log] of receipt.logs.entries()) {
      console.log("");
      console.log(`Log #${index}`);
      console.log("----------------------------------------------");
      console.log(`Address: ${log.address}`);

      console.log("Topics:");
      if (log.topics.length === 0) {
        console.log("  (none)");
      } else {
        for (const topic of log.topics) {
          console.log(`  ${topic}`);
        }
      }

      console.log(`Data: ${log.data}`);
    }
  }

  console.log("");
  console.log("==============================================");
  console.log("Inspection complete");
  console.log("==============================================");
}

main().catch((error) => {
  console.error("");
  console.error("Inspection failed:");

  if (error instanceof Error) {
    console.error(error.message);
  } else {
    console.error(error);
  }

  process.exit(1);
});