// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {CoopVault} from "../../src/CoopVault.sol";
import {Savings} from "../../src/Savings.sol";
import {CreditScore} from "../../src/CreditScore.sol";
import {ActuarialEngine} from "../../src/ActuarialEngine.sol";
import {LoanEngine} from "../../src/LoanEngine.sol";

contract DeployCoopChain is Script {
    address private constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    address private constant ARC_TREASURY = 0xA65e8F2B43687bBdc3739B7268eA355c2cf55701;

    function run()
        external
        returns (
            CoopVault coopVault,
            Savings savings,
            CreditScore creditScore,
            ActuarialEngine actuarialEngine,
            LoanEngine loanEngine
        )
    {
        vm.startBroadcast();

        coopVault = new CoopVault();

        savings = new Savings(ARC_TESTNET_USDC, address(coopVault));

        creditScore = new CreditScore(address(coopVault), address(savings));

        actuarialEngine = new ActuarialEngine();

        loanEngine = new LoanEngine(
            address(coopVault),
            address(savings),
            address(creditScore),
            address(actuarialEngine),
            ARC_TESTNET_USDC,
            ARC_TREASURY
        );

        vm.stopBroadcast();
    }
}
