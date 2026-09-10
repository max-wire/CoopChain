// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {InvestmentRegistry} from "../../../src/Investment/InvestmentRegistry.sol";
import {IInvestmentRegistry} from "../../../src/interfaces/IInvestmentRegistry.sol";
import {HederaTokenization} from "../../../src/sponsors/Hedera/HederaTokenization.sol";
import {IHederaTokenization} from "../../../src/sponsors/Hedera/interfaces/IHederaTokenization.sol";

contract HederaInvestmentIntegrationTest is Test {
    InvestmentRegistry private registry;
    HederaTokenization private hedera;

    address private admin = makeAddr("admin");
    address private issuer = makeAddr("issuer");

    // Verified Hedera ATS CCREF security EVM address.
    address private constant CCREF = 0x92EFe5B72783352675Ce84B65604e87ceE6b44C9;

    string private constant CCREF_HEDERA_ID = "0.0.10454483";

    string private constant INVESTMENT_NAME = "CoopChain Real Estate Fund";

    string private constant INVESTMENT_SYMBOL = "CCREF";

    uint256 private constant CCREF_PRICE = 1e18;
    uint256 private constant CCREF_SUPPLY = 1_000_000;

    function setUp() public {
        vm.startPrank(admin);

        registry = new InvestmentRegistry();
        hedera = new HederaTokenization();

        vm.stopPrank();
    }

    function test_RegisterCCREFInvestmentAndHederaAsset() public {
        // ----------------------------------------------------------
        // 1. Register CCREF in the CoopChain InvestmentRegistry
        // ----------------------------------------------------------

        vm.prank(admin);

        uint256 investmentId = registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.REAL_ESTATE,
            CCREF,
            issuer,
            CCREF_PRICE,
            CCREF_SUPPLY
        );

        // ----------------------------------------------------------
        // 2. Register the corresponding Hedera security
        // ----------------------------------------------------------

        vm.prank(admin);

        hedera.registerAsset(investmentId, CCREF_HEDERA_ID, INVESTMENT_NAME, INVESTMENT_SYMBOL);

        // ----------------------------------------------------------
        // 3. Read the CoopChain investment
        // ----------------------------------------------------------

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        // ----------------------------------------------------------
        // 4. Read the Hedera asset association
        // ----------------------------------------------------------

        IHederaTokenization.HederaAsset memory asset = hedera.getAsset(investmentId);

        // ----------------------------------------------------------
        // 5. Verify the integration
        // ----------------------------------------------------------

        assertEq(investment.id, investmentId);
        assertEq(investment.name, INVESTMENT_NAME);
        assertEq(investment.symbol, INVESTMENT_SYMBOL);

        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.REAL_ESTATE));

        assertEq(investment.token, CCREF);
        assertEq(investment.issuer, issuer);
        assertEq(investment.price, CCREF_PRICE);
        assertEq(investment.totalSupply, CCREF_SUPPLY);
        assertTrue(investment.active);

        assertEq(asset.investmentId, investmentId);
        assertEq(asset.securityAddress, CCREF_HEDERA_ID);
        assertEq(asset.name, INVESTMENT_NAME);
        assertEq(asset.symbol, INVESTMENT_SYMBOL);
        assertTrue(asset.active);

        assertTrue(registry.isInvestmentActive(investmentId));
        assertTrue(hedera.isRegistered(investmentId));
    }

    function test_CooperativeInvestmentPointsToCCREF() public {
        vm.prank(admin);

        uint256 investmentId = registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.REAL_ESTATE,
            CCREF,
            issuer,
            CCREF_PRICE,
            CCREF_SUPPLY
        );

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.token, CCREF);
        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.REAL_ESTATE));
    }

    function test_HederaAssetMapsToSameInvestmentId() public {
        vm.prank(admin);

        uint256 investmentId = registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.REAL_ESTATE,
            CCREF,
            issuer,
            CCREF_PRICE,
            CCREF_SUPPLY
        );

        vm.prank(admin);

        hedera.registerAsset(investmentId, CCREF_HEDERA_ID, INVESTMENT_NAME, INVESTMENT_SYMBOL);

        IHederaTokenization.HederaAsset memory asset = hedera.getAsset(investmentId);

        assertEq(asset.investmentId, investmentId);
    }

    function test_HederaAssetCanBeDeactivatedWithoutChangingRegistry() public {
        vm.prank(admin);

        uint256 investmentId = registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.REAL_ESTATE,
            CCREF,
            issuer,
            CCREF_PRICE,
            CCREF_SUPPLY
        );

        vm.prank(admin);

        hedera.registerAsset(investmentId, CCREF_HEDERA_ID, INVESTMENT_NAME, INVESTMENT_SYMBOL);

        vm.prank(admin);

        hedera.deactivateAsset(investmentId);

        IHederaTokenization.HederaAsset memory asset = hedera.getAsset(investmentId);

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertFalse(asset.active);

        // Deactivating the Hedera association does not automatically
        // deactivate the CoopChain investment.
        assertTrue(investment.active);
        assertTrue(registry.isInvestmentActive(investmentId));
    }
}
