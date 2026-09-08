// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {InvestmentRegistry} from "../../src/Investment/InvestmentRegistry.sol";
import {InvestmentToken} from "../../src/Investment/InvestmentToken.sol";
import {InvestmentPool} from "../../src/Investment/InvestmentPool.sol";

contract DeployInvestments is Script {
    address private constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    function run() external returns (InvestmentRegistry registry, InvestmentToken token, InvestmentPool pool) {
        vm.startBroadcast();

        // 1. Deploy registry.
        registry = new InvestmentRegistry();

        // 2. Deploy investment token.
        // The deployer is the temporary minter.
        token = new InvestmentToken("CoopChain Real Estate Fund", "CCREF", 1, msg.sender, 1_000_000e18, msg.sender);

        // 3. Deploy investment pool.
        pool = new InvestmentPool(ARC_TESTNET_USDC, address(registry));

        // 4. Transfer minting authority to InvestmentPool.
        token.setMinter(address(pool));

        vm.stopBroadcast();
    }
}
