// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {InvestmentRegistry} from "../../src/Investment/InvestmentRegistry.sol";
import {InvestmentToken} from "../../src/Investment/InvestmentToken.sol";
import {InvestmentPool} from "../../src/Investment/InvestmentPool.sol";
import {IInvestmentRegistry} from "../../src/interfaces/IInvestmentRegistry.sol";

contract InvestmentIntegrationTest is Test {
    /*//////////////////////////////////////////////////////////////
                                CONTRACTS
    //////////////////////////////////////////////////////////////*/

    InvestmentRegistry internal registry;
    InvestmentToken internal investmentToken;
    InvestmentPool internal pool;
    ERC20Mock internal usdc;

    /*//////////////////////////////////////////////////////////////
                                ACTORS
    //////////////////////////////////////////////////////////////*/

    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant INVESTMENT_ID = 1;

    uint256 internal constant INITIAL_PRICE = 1e18;
    uint256 internal constant UPDATED_PRICE = 1.2e18;

    uint256 internal constant MAX_SUPPLY = 1_000_000 ether;

    uint256 internal constant ALICE_INVESTMENT = 1_000 ether;
    uint256 internal constant BOB_INVESTMENT = 500 ether;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy stablecoin mock.
        usdc = new ERC20Mock();

        // 2. Deploy investment registry.
        registry = new InvestmentRegistry();

        // 3. Deploy investment token.
        //
        // Initial minter is admin. The pool receives the minter
        // role after deployment.
        investmentToken = new InvestmentToken("Coop Investment", "CINV", INVESTMENT_ID, admin, MAX_SUPPLY, admin);

        // 4. Deploy investment pool.
        pool = new InvestmentPool(address(usdc), address(registry));

        // 5. Transfer mint/burn authority to the pool.
        investmentToken.setMinter(address(pool));

        // 6. Register the investment.
        registry.createInvestment(
            "Coop Investment",
            "CINV",
            IInvestmentRegistry.AssetType.FUND,
            address(investmentToken),
            admin,
            INITIAL_PRICE,
            MAX_SUPPLY
        );

        vm.stopPrank();

        // Give investors USDC.
        usdc.mint(alice, 10_000 ether);
        usdc.mint(bob, 10_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        FULL INVESTMENT LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    function test_FullInvestmentLifecycle() public {
        // ---------------------------------------------------------
        // STEP 1: Verify registry
        // ---------------------------------------------------------

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(INVESTMENT_ID);

        assertEq(investment.id, INVESTMENT_ID);
        assertEq(investment.name, "Coop Investment");
        assertEq(investment.symbol, "CINV");
        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.FUND));
        assertEq(investment.token, address(investmentToken));
        assertEq(investment.issuer, admin);
        assertEq(investment.price, INITIAL_PRICE);
        assertEq(investment.totalSupply, MAX_SUPPLY);
        assertTrue(investment.active);

        // ---------------------------------------------------------
        // STEP 2: Alice invests
        // ---------------------------------------------------------

        vm.startPrank(alice);

        usdc.approve(address(pool), ALICE_INVESTMENT);

        uint256 aliceTokens = pool.invest(INVESTMENT_ID, ALICE_INVESTMENT);

        vm.stopPrank();

        // At a price of 1 USDC per token:
        // 1,000 USDC -> 1,000 CINV
        assertEq(aliceTokens, 1_000 ether);

        assertEq(investmentToken.balanceOf(alice), 1_000 ether);

        assertEq(usdc.balanceOf(address(pool)), ALICE_INVESTMENT);

        // ---------------------------------------------------------
        // STEP 3: Bob invests
        // ---------------------------------------------------------

        vm.startPrank(bob);

        usdc.approve(address(pool), BOB_INVESTMENT);

        uint256 bobTokens = pool.invest(INVESTMENT_ID, BOB_INVESTMENT);

        vm.stopPrank();

        assertEq(bobTokens, 500 ether);

        assertEq(investmentToken.balanceOf(bob), 500 ether);

        // Pool now holds both investments.
        assertEq(usdc.balanceOf(address(pool)), 1_500 ether);

        // Total outstanding investment tokens.
        assertEq(investmentToken.totalSupply(), 1_500 ether);

        // ---------------------------------------------------------
        // STEP 4: Investment price increases
        // ---------------------------------------------------------

        vm.prank(admin);

        registry.updateInvestment(INVESTMENT_ID, UPDATED_PRICE, MAX_SUPPLY);

        investment = registry.getInvestment(INVESTMENT_ID);

        assertEq(investment.price, UPDATED_PRICE);

        // ---------------------------------------------------------
        // STEP 5: Check Alice's new investment value
        // ---------------------------------------------------------

        uint256 aliceValue = pool.getInvestmentValue(INVESTMENT_ID, alice);

        // Alice owns 1,000 tokens.
        // New price = 1.20 USDC.
        // Value = 1,200 USDC.
        assertEq(aliceValue, 1_200 ether);

        // ---------------------------------------------------------
        // STEP 6: Alice redeems all tokens
        // ---------------------------------------------------------

        uint256 aliceUSDCBefore = usdc.balanceOf(alice);

        vm.prank(alice);

        uint256 aliceRedeemed = pool.redeem(INVESTMENT_ID, 1_000 ether);

        assertEq(aliceRedeemed, 1_200 ether);

        // Alice receives the increased value.
        assertEq(usdc.balanceOf(alice), aliceUSDCBefore + 1_200 ether);

        // Alice no longer owns investment tokens.
        assertEq(investmentToken.balanceOf(alice), 0);

        // Total supply now only represents Bob's position.
        assertEq(investmentToken.totalSupply(), 500 ether);

        // ---------------------------------------------------------
        // STEP 7: Bob remains invested
        // ---------------------------------------------------------

        assertEq(investmentToken.balanceOf(bob), 500 ether);

        uint256 bobValue = pool.getInvestmentValue(INVESTMENT_ID, bob);

        assertEq(bobValue, 600 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTIPLE INVESTORS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleInvestorsHaveIndependentPositions() public {
        vm.startPrank(alice);

        usdc.approve(address(pool), ALICE_INVESTMENT);

        pool.invest(INVESTMENT_ID, ALICE_INVESTMENT);

        vm.stopPrank();

        vm.startPrank(bob);

        usdc.approve(address(pool), BOB_INVESTMENT);

        pool.invest(INVESTMENT_ID, BOB_INVESTMENT);

        vm.stopPrank();

        assertEq(investmentToken.balanceOf(alice), 1_000 ether);

        assertEq(investmentToken.balanceOf(bob), 500 ether);

        assertEq(investmentToken.totalSupply(), 1_500 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE UPDATE + REDEMPTION
    //////////////////////////////////////////////////////////////*/

    function test_PriceIncreaseChangesRedemptionValue() public {
        vm.startPrank(alice);

        usdc.approve(address(pool), 1_000 ether);
        pool.invest(INVESTMENT_ID, 1_000 ether);

        vm.stopPrank();

        // Initial value.
        assertEq(pool.getInvestmentValue(INVESTMENT_ID, alice), 1_000 ether);

        // Increase price from 1.00 -> 1.50.
        vm.prank(admin);

        registry.updateInvestment(INVESTMENT_ID, 1.5e18, MAX_SUPPLY);

        // Alice still owns 1,000 tokens,
        // but their current value is now 1,500 USDC.
        assertEq(pool.getInvestmentValue(INVESTMENT_ID, alice), 1_500 ether);

        // Fund the pool so it has enough liquidity
        // to honor the increased redemption value.
        vm.startPrank(bob);

        usdc.approve(address(pool), 500 ether);
        pool.fund(500 ether);

        vm.stopPrank();

        vm.prank(alice);

        uint256 redeemed = pool.redeem(INVESTMENT_ID, 1_000 ether);

        assertEq(redeemed, 1_500 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        POOL LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function test_PoolLiquidityMatchesOutstandingPositions() public {
        vm.startPrank(alice);

        usdc.approve(address(pool), 1_000 ether);

        pool.invest(INVESTMENT_ID, 1_000 ether);

        vm.stopPrank();

        vm.startPrank(bob);

        usdc.approve(address(pool), 500 ether);

        pool.invest(INVESTMENT_ID, 500 ether);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), 1_500 ether);

        assertEq(investmentToken.totalSupply(), 1_500 ether);

        assertEq(pool.getInvestmentValue(INVESTMENT_ID, alice), 1_000 ether);

        assertEq(pool.getInvestmentValue(INVESTMENT_ID, bob), 500 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            TOKEN HANDOFF
    //////////////////////////////////////////////////////////////*/

    function test_PoolIsInvestmentTokenMinter() public view {
        assertEq(investmentToken.minter(), address(pool));

        assertFalse(investmentToken.minter() == admin);
    }
}
