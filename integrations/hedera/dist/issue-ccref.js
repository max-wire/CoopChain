import { ethers } from "ethers";
import "dotenv/config";
import { config } from "./config.js";
const FACTORY_ADDRESS = "0x5fA65CA30d1984701F10476664327f97c864A9D3";
const BLR_ADDRESS = "0xEFEF4CAe9642631Cfc6d997D6207Ee48fa78fe42";
const EQUITY_CONFIG_ID = "0x0000000000000000000000000000000000000000000000000000000000000001";
// Factory ABI — ATS 4.2.0 / deployed Hedera Testnet Factory.
const FACTORY_ABI = [
    "function deployEquity(tuple(tuple(bool,bool,address,tuple(bytes32,uint256),tuple(bytes32,address[])[],bool,bool,uint256,tuple(string,string,string,uint8),bool,bool,address[],address[],address[],bool,address,address),tuple(bool,bool,bool,bool,bool,bool,bool,uint8,bytes3,uint256,uint8)),tuple(uint8,uint8,tuple(bool,string,string))) returns (address)",
];
const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
function requireEnv(name) {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing environment variable: ${name}`);
    }
    return value;
}
async function main() {
    console.log("==============================================");
    console.log("CoopChain — Hedera ATS Equity Issuance");
    console.log("==============================================");
    const provider = new ethers.JsonRpcProvider(config.rpcUrl);
    const privateKey = requireEnv("HEDERA_PRIVATE_KEY");
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`Admin EVM address: ${wallet.address}`);
    console.log(`Factory: ${FACTORY_ADDRESS}`);
    console.log(`BLR: ${BLR_ADDRESS}`);
    const network = await provider.getNetwork();
    console.log(`Chain ID: ${network.chainId}`);
    if (network.chainId !== 296n) {
        throw new Error(`Wrong network. Expected Hedera Testnet chain ID 296, got ${network.chainId}`);
    }
    const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, wallet);
    /*
     * ------------------------------------------------------------
     * SECURITY DATA
     * ------------------------------------------------------------
     *
     * IMPORTANT:
     * The ATS 4.2.0 ABI contains unnamed tuple components.
     * Therefore, deployEquity arguments are supplied positionally
     * as arrays instead of JavaScript objects.
     */
    const securityDataArgs = [
        false, // arePartitionsProtected
        false, // isMultiPartition
        BLR_ADDRESS,
        // ResolverProxyConfiguration
        [
            EQUITY_CONFIG_ID,
            1n,
        ],
        // RBAC configuration
        [
            [
                DEFAULT_ADMIN_ROLE,
                [wallet.address],
            ],
        ],
        true, // isControllable
        true, // isWhiteList
        1000000n, // maxSupply
        // ERC20MetadataInfo
        [
            "CoopChain Real Estate Fund",
            "CCREF",
            "KE0000000091",
            18,
        ],
        false, // clearingActive
        true, // internalKycActivated
        [], // externalPauses
        [], // externalControlLists
        [], // externalKycLists
        false, // erc20VotesActivated
        ethers.ZeroAddress, // compliance
        ethers.ZeroAddress, // identityRegistry
    ];
    /*
     * ------------------------------------------------------------
     * EQUITY DETAILS
     * ------------------------------------------------------------
     */
    const equityDetailsArgs = [
        false, // votingRight
        true, // informationRight
        false, // liquidationRight
        true, // subscriptionRight
        false, // conversionRight
        true, // redemptionRight
        false, // putRight
        0, // dividendRight
        ethers.hexlify(ethers.toUtf8Bytes("USD")), // currency
        1n, // nominalValue
        0, // nominalValueDecimals
    ];
    /*
     * ------------------------------------------------------------
     * EQUITY DATA
     * ------------------------------------------------------------
     *
     * deployEquity expects:
     *
     * equityData = (
     *   securityData,
     *   equityDetails
     * )
     *
     * Both nested tuples are therefore supplied positionally.
     */
    const equityDataArgs = [
        securityDataArgs,
        equityDetailsArgs,
    ];
    /*
     * ------------------------------------------------------------
     * FACTORY REGULATION DATA
     * ------------------------------------------------------------
     *
     * deployEquity expects:
     *
     * factoryRegulationData = (
     *   regulationType,
     *   regulationSubType,
     *   additionalSecurityData
     * )
     */
    const factoryRegulationDataArgs = [
        2, // regulationType
        1, // regulationSubType
        // AdditionalSecurityData
        [
            false, // countriesControlListType
            "",
            "CoopChain Real Estate Fund — Hedera Testnet",
        ],
    ];
    console.log("");
    console.log("Issuing ATS equity:");
    console.log("  Name:        CoopChain Real Estate Fund");
    console.log("  Symbol:      CCREF");
    console.log("  Max supply:  1,000,000");
    console.log("  Decimals:    18");
    console.log("  Currency:    USD");
    console.log("  Whitelist:   enabled");
    console.log("  Internal KYC: enabled");
    console.log("");
    /*
     * ------------------------------------------------------------
     * GAS ESTIMATION
     * ------------------------------------------------------------
     */
    console.log("Estimating gas...");
    const gasEstimate = await factory.deployEquity.estimateGas(equityDataArgs, factoryRegulationDataArgs);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);
    /*
     * ------------------------------------------------------------
     * DEPLOY EQUITY
     * ------------------------------------------------------------
     */
    console.log("");
    console.log("Sending deployEquity transaction...");
    const tx = await factory.deployEquity(equityDataArgs, factoryRegulationDataArgs, {
        gasLimit: (gasEstimate * 120n) / 100n,
    });
    console.log(`Transaction hash: ${tx.hash}`);
    console.log("Waiting for confirmation...");
    const receipt = await tx.wait();
    if (!receipt) {
        throw new Error("Transaction receipt not returned");
    }
    console.log(`Confirmed in block: ${receipt.blockNumber}`);
    /*
     * ------------------------------------------------------------
     * TRANSACTION SUCCESS
     * ------------------------------------------------------------
     *
     * ATS 4.2.0 ABI currently contains no EquityDeployed event.
     * Therefore, do not attempt to extract an equity/security
     * address from the transaction receipt yet.
     */
    console.log("");
    console.log("==============================================");
    console.log("CCREF ISSUED SUCCESSFULLY");
    console.log("==============================================");
    console.log(`Transaction: ${tx.hash}`);
    console.log("");
    console.log(`HashScan transaction: https://hashscan.io/testnet/transaction/${tx.hash}`);
    console.log("==============================================");
}
main().catch((error) => {
    console.error("");
    console.error("CCREF issuance failed:");
    if (error instanceof Error) {
        console.error(error.message);
    }
    else {
        console.error(error);
    }
    process.exit(1);
});
