// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {InvestmentPool} from "../../src/Investment/InvestmentPool.sol";
import {InvestmentToken} from "../../src/Investment/InvestmentToken.sol";

import {IInvestmentToken} from "../../src/interfaces/IInvestmentToken.sol";
import {IInvestmentPool} from "../../src/interfaces/IInvestmentPool.sol";
import {IInvestmentRegistry} from "../../src/interfaces/IInvestmentRegistry.sol";

import {MathHelper} from "../libraries/MathHelper.sol";
import {MockUSDC} from "../mock/MockUSDC.sol";

contract MockInvestmentRegistry {
    mapping(uint256 => IInvestmentRegistry.Investment) private s_investments;

    error InvestmentNotFound();

    function setInvestment(
        uint256 investmentId,
        string memory name,
        string memory symbol,
        IInvestmentRegistry.AssetType assetType,
        address token,
        address issuer,
        uint256 price,
        uint256 totalSupply,
        bool active
    ) external {
        s_investments[investmentId] = IInvestmentRegistry.Investment({
            id: investmentId,
            name: name,
            symbol: symbol,
            assetType: assetType,
            token: token,
            issuer: issuer,
            price: price,
            totalSupply: totalSupply,
            active: active
        });
    }

    function getInvestment(uint256 investmentId)
        external
        view
        returns (IInvestmentRegistry.Investment memory investment)
    {
        investment = s_investments[investmentId];

        if (investment.id == 0) {
            revert InvestmentNotFound();
        }
    }
}

/*//////////////////////////////////////////////////////////////
                       INVESTMENT POOL TEST
//////////////////////////////////////////////////////////////*/

contract InvestmentPoolTest is Test {
    /*//////////////////////////////////////////////////////////////
                              CONTRACTS
    //////////////////////////////////////////////////////////////*/

    MockUSDC internal usdc;
    MockInvestmentRegistry internal registry;
    InvestmentToken internal investmentToken;
    InvestmentPool internal pool;

    /*//////////////////////////////////////////////////////////////
                              ACCOUNTS
    //////////////////////////////////////////////////////////////*/

    address internal admin = makeAddr("admin");
    address internal investor = makeAddr("investor");
    address internal investorTwo = makeAddr("investorTwo");
    address internal funder = makeAddr("funder");
    address internal recipient = makeAddr("recipient");
    address internal unauthorized = makeAddr("unauthorized");

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant INVESTMENT_ID = 1;

    uint256 internal constant PRICE = 100e6;

    uint256 internal constant INVESTMENT_AMOUNT = 1_000e6;

    uint256 internal constant TOKEN_AMOUNT = 10e18;

    uint256 internal constant INITIAL_USDC = 1_000_000e6;

    uint256 internal constant MAX_SUPPLY = 1_000_000e18;

    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.startPrank(admin);

        usdc = new MockUSDC();

        registry = new MockInvestmentRegistry();

        /*
         * InvestmentToken initially uses admin as the minter.
         *
         * Deployment sequence:
         *
         * Registry
         *     ↓
         * InvestmentToken(admin)
         *     ↓
         * InvestmentPool
         *     ↓
         * token.setMinter(pool)
         *     ↓
         * register investment
         */
        investmentToken = new InvestmentToken("Coop Investment Token", "CINV", INVESTMENT_ID, admin, MAX_SUPPLY, admin);

        pool = new InvestmentPool(address(usdc), address(registry));

        /*
         * Transfer mint/burn authority from admin to InvestmentPool.
         */
        investmentToken.setMinter(address(pool));

        /*
         * Register the investment in the mock registry.
         */
        registry.setInvestment(
            INVESTMENT_ID,
            "Coop Investment",
            "CINV",
            IInvestmentRegistry.AssetType.FUND,
            address(investmentToken),
            admin,
            PRICE,
            MAX_SUPPLY,
            true
        );

        vm.stopPrank();

        /*
         * Fund test accounts with USDC.
         */
        usdc.mint(investor, INITIAL_USDC);
        usdc.mint(investorTwo, INITIAL_USDC);
        usdc.mint(funder, INITIAL_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                         CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ConstructorSetsStablecoin() public view {
        assertEq(pool.stablecoin(), address(usdc));
    }

    function test_ConstructorSetsInvestmentRegistry() public view {
        assertEq(pool.investmentRegistry(), address(registry));
    }

    function test_ConstructorSetsAdmin() public view {
        assertEq(pool.admin(), admin);
    }

    function test_RevertWhenStablecoinIsZeroAddress() public {
        vm.expectRevert(IInvestmentPool.InvalidAddress.selector);

        new InvestmentPool(address(0), address(registry));
    }

    function test_RevertWhenRegistryIsZeroAddress() public {
        vm.expectRevert(IInvestmentPool.InvalidAddress.selector);

        new InvestmentPool(address(usdc), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                      DEPLOYMENT HANDOFF TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialMinterIsPool() public view {
        assertEq(investmentToken.minter(), address(pool));
    }

    function test_AdminCanNoLongerMintAfterHandoff() public {
        vm.prank(admin);

        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        investmentToken.mint(investor, TOKEN_AMOUNT);
    }

    function test_AdminCanNoLongerBurnAfterHandoff() public {
        vm.prank(admin);

        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        investmentToken.burn(investor, TOKEN_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                         INVESTMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InvestTransfersUSDCToPool() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), INVESTMENT_AMOUNT);

        assertEq(usdc.balanceOf(investor), INITIAL_USDC - INVESTMENT_AMOUNT);
    }

    function test_InvestMintsCorrectTokenAmount() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        uint256 tokenAmount = pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        assertEq(tokenAmount, TOKEN_AMOUNT);

        assertEq(investmentToken.balanceOf(investor), TOKEN_AMOUNT);
    }

    function test_InvestUpdatesTokenTotalSupply() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        assertEq(investmentToken.totalSupply(), TOKEN_AMOUNT);
    }

    function test_InvestEmitsInvestmentPurchased() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        vm.expectEmit(true, true, false, true);

        emit IInvestmentPool.InvestmentPurchased(investor, INVESTMENT_ID, INVESTMENT_AMOUNT, TOKEN_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();
    }

    function test_InvestMultipleTimes() public {
        uint256 firstInvestment = 500e6;
        uint256 secondInvestment = 300e6;

        vm.startPrank(investor);

        usdc.approve(address(pool), firstInvestment + secondInvestment);

        pool.invest(INVESTMENT_ID, firstInvestment);

        pool.invest(INVESTMENT_ID, secondInvestment);

        vm.stopPrank();

        uint256 expectedTokens = MathHelper.tokenAmount(firstInvestment + secondInvestment, PRICE);

        assertEq(investmentToken.balanceOf(investor), expectedTokens);

        assertEq(usdc.balanceOf(address(pool)), firstInvestment + secondInvestment);
    }

    function test_MultipleInvestorsCanInvest() public {
        uint256 investorOneAmount = 1_000e6;
        uint256 investorTwoAmount = 2_000e6;

        vm.startPrank(investor);

        usdc.approve(address(pool), investorOneAmount);

        pool.invest(INVESTMENT_ID, investorOneAmount);

        vm.stopPrank();

        vm.startPrank(investorTwo);

        usdc.approve(address(pool), investorTwoAmount);

        pool.invest(INVESTMENT_ID, investorTwoAmount);

        vm.stopPrank();

        assertEq(investmentToken.balanceOf(investor), 10e18);

        assertEq(investmentToken.balanceOf(investorTwo), 20e18);
    }

    /*//////////////////////////////////////////////////////////////
                         INVESTMENT REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhenInvestingZeroAmount() public {
        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        vm.prank(investor);

        pool.invest(INVESTMENT_ID, 0);
    }

    function test_RevertWhenInvestmentDoesNotExist() public {
        vm.expectRevert(IInvestmentPool.InvestmentNotFound.selector);

        vm.prank(investor);

        pool.invest(999, INVESTMENT_AMOUNT);
    }

    function test_RevertWhenInvestmentIsInactive() public {
        registry.setInvestment(
            INVESTMENT_ID,
            "Coop Investment",
            "CINV",
            IInvestmentRegistry.AssetType.FUND,
            address(investmentToken),
            admin,
            PRICE,
            MAX_SUPPLY,
            false
        );

        vm.expectRevert(IInvestmentPool.InvestmentInactive.selector);

        vm.prank(investor);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);
    }

    function test_RevertWhenInvestmentTokenIsZeroAddress() public {
        registry.setInvestment(
            INVESTMENT_ID,
            "Coop Investment",
            "CINV",
            IInvestmentRegistry.AssetType.FUND,
            address(0),
            admin,
            PRICE,
            MAX_SUPPLY,
            true
        );

        vm.expectRevert(IInvestmentPool.InvalidToken.selector);

        vm.prank(investor);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);
    }

    function test_RevertWhenCalculatedTokenAmountIsZero() public {
        /*
         * Price is greater than the investment amount, resulting
         * in a calculated token amount of zero.
         */
        registry.setInvestment(
            INVESTMENT_ID,
            "Expensive Investment",
            "EXP",
            IInvestmentRegistry.AssetType.FUND,
            address(investmentToken),
            admin,
            type(uint256).max,
            MAX_SUPPLY,
            true
        );

        vm.startPrank(investor);

        usdc.approve(address(pool), 1);

        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        pool.invest(INVESTMENT_ID, 1);

        vm.stopPrank();
    }

    function test_RevertWhenInvestorHasInsufficientUSDCAllowance() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT - 1);

        vm.expectRevert();

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemReturnsUSDC() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        uint256 balanceBefore = usdc.balanceOf(investor);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);

        uint256 balanceAfter = usdc.balanceOf(investor);

        vm.stopPrank();

        assertEq(balanceAfter, balanceBefore + INVESTMENT_AMOUNT);
    }

    function test_RedeemBurnsInvestmentTokens() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        assertEq(investmentToken.balanceOf(investor), TOKEN_AMOUNT);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);

        vm.stopPrank();

        assertEq(investmentToken.balanceOf(investor), 0);
    }

    function test_RedeemDecreasesTotalSupply() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);

        vm.stopPrank();

        assertEq(investmentToken.totalSupply(), 0);
    }

    function test_RedeemEmitsInvestmentRedeemed() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.expectEmit(true, true, false, true);

        emit IInvestmentPool.InvestmentRedeemed(investor, INVESTMENT_ID, TOKEN_AMOUNT, INVESTMENT_AMOUNT);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);

        vm.stopPrank();
    }

    function test_RedeemUsesCurrentInvestmentPrice() public {
        uint256 originalPrice = PRICE;
        uint256 newPrice = 120e6;

        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        registry.setInvestment(
            INVESTMENT_ID,
            "Test Investment",
            "TEST",
            IInvestmentRegistry.AssetType.EQUITY,
            address(investmentToken),
            admin,
            newPrice,
            MAX_SUPPLY,
            true
        );

        // Add enough liquidity to cover the new valuation.
        uint256 redemptionValue = MathHelper.usdcAmount(TOKEN_AMOUNT, newPrice);

        uint256 currentPoolBalance = usdc.balanceOf(address(pool));

        uint256 additionalFunding = redemptionValue > currentPoolBalance ? redemptionValue - currentPoolBalance : 0;

        if (additionalFunding > 0) {
            vm.startPrank(funder);

            usdc.approve(address(pool), additionalFunding);

            pool.fund(additionalFunding);

            vm.stopPrank();
        }

        vm.startPrank(investor);

        uint256 usdcBefore = usdc.balanceOf(investor);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);

        uint256 usdcAfter = usdc.balanceOf(investor);

        vm.stopPrank();

        assertEq(usdcAfter - usdcBefore, redemptionValue);

        assertEq(redemptionValue, 1_200e6);

        assertEq(originalPrice, PRICE);
    }

    function test_RedeemPartialBalance() public {
        uint256 partialTokens = 4e18;

        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        pool.redeem(INVESTMENT_ID, partialTokens);

        vm.stopPrank();

        assertEq(investmentToken.balanceOf(investor), 6e18);
    }

    /*//////////////////////////////////////////////////////////////
                        REDEMPTION REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhenRedeemingZeroTokens() public {
        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        vm.prank(investor);

        pool.redeem(INVESTMENT_ID, 0);
    }

    function test_RevertWhenRedeemingWithoutTokens() public {
        vm.expectRevert(IInvestmentPool.InsufficientTokenBalance.selector);

        vm.prank(investor);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);
    }

    function test_RevertWhenRedeemingMoreThanBalance() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.expectRevert(IInvestmentPool.InsufficientTokenBalance.selector);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT + 1);

        vm.stopPrank();
    }

    function test_RevertWhenPoolHasInsufficientLiquidity() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        /*
         * Withdraw all pool liquidity first.
         */
        vm.prank(admin);

        pool.withdraw(admin, INVESTMENT_AMOUNT);

        vm.expectRevert(IInvestmentPool.InsufficientPoolBalance.selector);

        vm.prank(investor);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);
    }

    function test_RevertWhenRedeemingInactiveInvestment() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        registry.setInvestment(
            INVESTMENT_ID,
            "Coop Investment",
            "CINV",
            IInvestmentRegistry.AssetType.FUND,
            address(investmentToken),
            admin,
            PRICE,
            MAX_SUPPLY,
            false
        );

        vm.expectRevert(IInvestmentPool.InvestmentInactive.selector);

        vm.prank(investor);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);
    }

    function test_RevertWhenRedeemingUnknownInvestment() public {
        vm.expectRevert(IInvestmentPool.InvestmentNotFound.selector);

        vm.prank(investor);

        pool.redeem(999, TOKEN_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                           FUNDING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FundAddsUSDCToPool() public {
        uint256 amount = 5_000e6;

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), amount);
    }

    function test_FundEmitsPoolFunded() public {
        uint256 amount = 5_000e6;

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        vm.expectEmit(true, false, false, true);

        emit IInvestmentPool.PoolFunded(funder, amount);

        pool.fund(amount);

        vm.stopPrank();
    }

    function test_AnyoneCanFundPool() public {
        uint256 amount = 1_000e6;

        vm.startPrank(unauthorized);

        usdc.mint(unauthorized, amount);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), amount);
    }

    function test_RevertWhenFundingZeroAmount() public {
        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        vm.prank(funder);

        pool.fund(0);
    }

    /*//////////////////////////////////////////////////////////////
                         WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AdminCanWithdraw() public {
        uint256 amount = 5_000e6;

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        uint256 recipientBefore = usdc.balanceOf(recipient);

        vm.prank(admin);

        pool.withdraw(recipient, amount);

        assertEq(usdc.balanceOf(recipient), recipientBefore + amount);

        assertEq(usdc.balanceOf(address(pool)), 0);
    }

    function test_WithdrawEmitsPoolWithdrawn() public {
        uint256 amount = 5_000e6;

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        vm.expectEmit(true, false, false, true);

        emit IInvestmentPool.PoolWithdrawn(recipient, amount);

        vm.prank(admin);

        pool.withdraw(recipient, amount);
    }

    function test_RevertWhenUnauthorizedWithdraws() public {
        uint256 amount = 1_000e6;

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        vm.expectRevert(IInvestmentPool.Unauthorized.selector);

        vm.prank(unauthorized);

        pool.withdraw(recipient, amount);
    }

    function test_RevertWhenWithdrawRecipientIsZeroAddress() public {
        uint256 amount = 1_000e6;

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        vm.expectRevert(IInvestmentPool.InvalidAddress.selector);

        vm.prank(admin);

        pool.withdraw(address(0), amount);
    }

    function test_RevertWhenWithdrawAmountIsZero() public {
        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        vm.prank(admin);

        pool.withdraw(recipient, 0);
    }

    function test_RevertWhenWithdrawExceedsPoolBalance() public {
        vm.expectRevert(IInvestmentPool.InsufficientPoolBalance.selector);

        vm.prank(admin);

        pool.withdraw(recipient, 1_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                       CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetTokenAmount() public view {
        uint256 amount = 1_000e6;

        uint256 result = pool.getTokenAmount(INVESTMENT_ID, amount);

        assertEq(result, 10e18);
    }

    function test_GetUSDCAmount() public view {
        uint256 tokenAmount = 10e18;

        uint256 result = pool.getUSDCAmount(INVESTMENT_ID, tokenAmount);

        assertEq(result, 1_000e6);
    }

    function test_GetInvestmentValueBeforeInvestment() public view {
        uint256 value = pool.getInvestmentValue(INVESTMENT_ID, investor);

        assertEq(value, 0);
    }

    function test_GetInvestmentValueAfterInvestment() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        uint256 value = pool.getInvestmentValue(INVESTMENT_ID, investor);

        assertEq(value, INVESTMENT_AMOUNT);
    }

    function test_GetInvestmentValueUsesCurrentPrice() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        vm.stopPrank();

        registry.setInvestment(
            INVESTMENT_ID,
            "Coop Investment",
            "CINV",
            IInvestmentRegistry.AssetType.FUND,
            address(investmentToken),
            admin,
            120e6,
            MAX_SUPPLY,
            true
        );

        uint256 value = pool.getInvestmentValue(INVESTMENT_ID, investor);

        assertEq(value, 1_200e6);
    }

    /*//////////////////////////////////////////////////////////////
                    CALCULATION REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhenGetTokenAmountIsZero() public {
        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        pool.getTokenAmount(INVESTMENT_ID, 0);
    }

    function test_RevertWhenGetUSDCAmountIsZero() public {
        vm.expectRevert(IInvestmentPool.InvalidAmount.selector);

        pool.getUSDCAmount(INVESTMENT_ID, 0);
    }

    function test_RevertWhenInvestmentValueInvestorIsZeroAddress() public {
        vm.expectRevert(IInvestmentPool.InvalidAddress.selector);

        pool.getInvestmentValue(INVESTMENT_ID, address(0));
    }

    function test_RevertWhenGetTokenAmountInvestmentDoesNotExist() public {
        vm.expectRevert(IInvestmentPool.InvestmentNotFound.selector);

        pool.getTokenAmount(999, INVESTMENT_AMOUNT);
    }

    function test_RevertWhenGetUSDCAmountInvestmentDoesNotExist() public {
        vm.expectRevert(IInvestmentPool.InvestmentNotFound.selector);

        pool.getUSDCAmount(999, TOKEN_AMOUNT);
    }

    function test_RevertWhenGetInvestmentValueInvestmentDoesNotExist() public {
        vm.expectRevert(IInvestmentPool.InvestmentNotFound.selector);

        pool.getInvestmentValue(999, investor);
    }

    /*//////////////////////////////////////////////////////////////
                       SUPPLY INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupplyMatchesOutstandingInvestorBalances() public {
        uint256 investorOneAmount = 1_000e6;
        uint256 investorTwoAmount = 2_000e6;

        vm.startPrank(investor);

        usdc.approve(address(pool), investorOneAmount);

        pool.invest(INVESTMENT_ID, investorOneAmount);

        vm.stopPrank();

        vm.startPrank(investorTwo);

        usdc.approve(address(pool), investorTwoAmount);

        pool.invest(INVESTMENT_ID, investorTwoAmount);

        vm.stopPrank();

        uint256 totalBalances = investmentToken.balanceOf(investor) + investmentToken.balanceOf(investorTwo);

        assertEq(investmentToken.totalSupply(), totalBalances);
    }

    function test_RedeemingAllTokensLeavesZeroSupply() public {
        vm.startPrank(investor);

        usdc.approve(address(pool), INVESTMENT_AMOUNT);

        pool.invest(INVESTMENT_ID, INVESTMENT_AMOUNT);

        pool.redeem(INVESTMENT_ID, TOKEN_AMOUNT);

        vm.stopPrank();

        assertEq(investmentToken.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                         FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_GetTokenAmount(uint256 usdcAmount) public view {
        usdcAmount = bound(usdcAmount, 1, 1_000_000e6);

        uint256 expected = MathHelper.tokenAmount(usdcAmount, PRICE);

        uint256 actual = pool.getTokenAmount(INVESTMENT_ID, usdcAmount);

        assertEq(actual, expected);
    }

    function testFuzz_GetUSDCAmount(uint256 tokenAmount) public view {
        tokenAmount = bound(tokenAmount, 1, 1_000_000e18);

        uint256 expected = MathHelper.usdcAmount(tokenAmount, PRICE);

        uint256 actual = pool.getUSDCAmount(INVESTMENT_ID, tokenAmount);

        assertEq(actual, expected);
    }

    function testFuzz_InvestWithinAvailableSupply(uint256 usdcAmount) public {
        /*
         * With price = 100 USDC, this range keeps the resulting
         * token amount below MAX_SUPPLY.
         */
        usdcAmount = bound(usdcAmount, 100e6, 1_000_000e6);

        usdc.mint(investor, usdcAmount);

        vm.startPrank(investor);

        usdc.approve(address(pool), usdcAmount);

        uint256 tokenAmount = pool.invest(INVESTMENT_ID, usdcAmount);

        vm.stopPrank();

        assertEq(investmentToken.balanceOf(investor), tokenAmount);

        assertEq(usdc.balanceOf(address(pool)), usdcAmount);
    }

    function testFuzz_InvestAndRedeemAtSamePrice(uint256 price) public {
        price = bound(price, 1e6, 1_000e6);

        registry.setInvestment(
            INVESTMENT_ID,
            "Test Investment",
            "TEST",
            IInvestmentRegistry.AssetType.EQUITY,
            address(investmentToken),
            admin,
            price,
            MAX_SUPPLY,
            true
        );

        uint256 usdcAmount = 1_000e6;

        vm.startPrank(investor);

        usdc.approve(address(pool), usdcAmount);

        uint256 usdcBefore = usdc.balanceOf(investor);

        uint256 tokenAmount = pool.invest(INVESTMENT_ID, usdcAmount);

        uint256 usdcAfterInvest = usdc.balanceOf(investor);

        uint256 expectedTokenAmount = MathHelper.tokenAmount(usdcAmount, price);

        assertEq(tokenAmount, expectedTokenAmount);

        assertEq(usdcBefore - usdcAfterInvest, usdcAmount);

        uint256 poolBalanceBeforeRedeem = usdc.balanceOf(address(pool));

        uint256 redeemedUSDC = pool.redeem(INVESTMENT_ID, tokenAmount);

        uint256 usdcAfterRedeem = usdc.balanceOf(investor);

        uint256 poolBalanceAfterRedeem = usdc.balanceOf(address(pool));

        uint256 expectedUSDCAmount = MathHelper.usdcAmount(tokenAmount, price);

        assertEq(redeemedUSDC, expectedUSDCAmount);

        assertEq(usdcAfterRedeem, usdcBefore - usdcAmount + expectedUSDCAmount);

        assertEq(poolBalanceBeforeRedeem - poolBalanceAfterRedeem, expectedUSDCAmount);

        vm.stopPrank();
    }

    function testFuzz_PartialRedemptionNeverExceedsBalance(uint256 usdcAmount, uint256 redemptionPercent) public {
        usdcAmount = bound(usdcAmount, 1e6, 1_000e6);
        redemptionPercent = bound(redemptionPercent, 1, 99);

        vm.startPrank(investor);

        usdc.approve(address(pool), usdcAmount);

        uint256 mintedTokens = pool.invest(INVESTMENT_ID, usdcAmount);

        uint256 redemptionAmount = (mintedTokens * redemptionPercent) / 100;

        vm.assume(redemptionAmount > 0);

        uint256 balanceBefore = investmentToken.balanceOf(investor);

        pool.redeem(INVESTMENT_ID, redemptionAmount);

        uint256 balanceAfter = investmentToken.balanceOf(investor);

        assertEq(balanceAfter, balanceBefore - redemptionAmount);

        assertLe(redemptionAmount, balanceBefore);

        vm.stopPrank();
    }

    function testFuzz_FundingIncreasesPoolBalance(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e6);

        usdc.mint(funder, amount);

        vm.startPrank(funder);

        usdc.approve(address(pool), amount);

        pool.fund(amount);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(pool)), amount);
    }

    function testFuzz_WithdrawalNeverExceedsPoolBalance(uint256 fundedAmount, uint256 withdrawalAmount) public {
        fundedAmount = bound(fundedAmount, 1, 1_000_000e6);

        withdrawalAmount = bound(withdrawalAmount, 1, fundedAmount);

        usdc.mint(funder, fundedAmount);

        vm.startPrank(funder);

        usdc.approve(address(pool), fundedAmount);

        pool.fund(fundedAmount);

        vm.stopPrank();

        vm.prank(admin);

        pool.withdraw(recipient, withdrawalAmount);

        assertEq(usdc.balanceOf(recipient), withdrawalAmount);

        assertEq(usdc.balanceOf(address(pool)), fundedAmount - withdrawalAmount);
    }
}

