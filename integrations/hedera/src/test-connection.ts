import { Client, AccountId, PrivateKey } from "@hashgraph/sdk";
import { config } from "./config.js";

async function main() {
  console.log("Connecting to Hedera Testnet...");
  console.log(`Account: ${config.accountId}`);

  const accountId = AccountId.fromString(config.accountId);
  const privateKey = PrivateKey.fromStringECDSA(config.privateKey);

  const client = Client.forTestnet();
  client.setOperator(accountId, privateKey);

  // Simple network call to confirm credentials and connectivity.
  const network = client.network;

  console.log("Hedera Testnet client initialized successfully.");
  console.log(`Network nodes: ${Object.keys(network).length}`);

  client.close();
}

main().catch((error) => {
  console.error("Connection failed:");
  console.error(error);
  process.exit(1);
});
