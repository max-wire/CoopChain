// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InvestmentToken} from "../../src/Investment/InvestmentToken.sol";
import {IInvestmentToken} from "../../src/interfaces/IInvestmentToken.sol";

contract InvestmentTokenTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    InvestmentToken public token;

    address internal issuer = makeAddr("issuer");
    address internal minter = makeAddr("minter");
    address internal newMinter = makeAddr("newMinter");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant INVESTMENT_ID = 1;
    uint256 internal constant MAX_SUPPLY = 1_000_000 ether;
    uint256 internal constant MINT_AMOUNT = 100 ether;

    string internal constant TOKEN_NAME = "Coop Equity";
    string internal constant TOKEN_SYMBOL = "COEQ";

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        token = new InvestmentToken(TOKEN_NAME, TOKEN_SYMBOL, INVESTMENT_ID, issuer, MAX_SUPPLY, minter);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsName() public view {
        assertEq(token.name(), TOKEN_NAME);
    }

    function test_Constructor_SetsSymbol() public view {
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    function test_Constructor_SetsInvestmentId() public view {
        assertEq(token.investmentId(), INVESTMENT_ID);
    }

    function test_Constructor_SetsIssuer() public view {
        assertEq(token.issuer(), issuer);
    }

    function test_Constructor_SetsMaxSupply() public view {
        assertEq(token.maxSupply(), MAX_SUPPLY);
    }

    function test_Constructor_SetsInitialMinter() public view {
        assertEq(token.minter(), minter);
    }

    function test_Constructor_StartsWithZeroSupply() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_Constructor_RevertsForZeroInvestmentId() public {
        vm.expectRevert(IInvestmentToken.InvalidInvestmentId.selector);

        new InvestmentToken(TOKEN_NAME, TOKEN_SYMBOL, 0, issuer, MAX_SUPPLY, minter);
    }

    function test_Constructor_RevertsForZeroIssuer() public {
        vm.expectRevert(IInvestmentToken.InvalidAddress.selector);

        new InvestmentToken(TOKEN_NAME, TOKEN_SYMBOL, INVESTMENT_ID, address(0), MAX_SUPPLY, minter);
    }

    function test_Constructor_RevertsForZeroMaxSupply() public {
        vm.expectRevert(IInvestmentToken.InvalidMaxSupply.selector);

        new InvestmentToken(TOKEN_NAME, TOKEN_SYMBOL, INVESTMENT_ID, issuer, 0, minter);
    }

    function test_Constructor_RevertsForZeroMinter() public {
        vm.expectRevert(IInvestmentToken.InvalidAddress.selector);

        new InvestmentToken(TOKEN_NAME, TOKEN_SYMBOL, INVESTMENT_ID, issuer, MAX_SUPPLY, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              MINTING
    //////////////////////////////////////////////////////////////*/

    function test_Mint_CreatesTokens() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        assertEq(token.balanceOf(alice), MINT_AMOUNT);
    }

    function test_Mint_IncreasesTotalSupply() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        assertEq(token.totalSupply(), MINT_AMOUNT);
    }

    function test_Mint_EmitsTokensMinted() public {
        vm.expectEmit(true, true, false, true);
        emit IInvestmentToken.TokensMinted(alice, MINT_AMOUNT);

        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
    }

    function test_Mint_AllowsMintingUpToMaximumSupply() public {
        vm.prank(minter);
        token.mint(alice, MAX_SUPPLY);

        assertEq(token.totalSupply(), MAX_SUPPLY);
        assertEq(token.balanceOf(alice), MAX_SUPPLY);
    }

    function test_Mint_RevertsWhenExceedingMaximumSupply() public {
        vm.prank(minter);
        token.mint(alice, MAX_SUPPLY);

        vm.expectRevert(IInvestmentToken.ExceedsMaxSupply.selector);

        vm.prank(minter);
        token.mint(alice, 1);
    }

    function test_Mint_RevertsForZeroAddress() public {
        vm.expectRevert(IInvestmentToken.InvalidAddress.selector);

        vm.prank(minter);
        token.mint(address(0), MINT_AMOUNT);
    }

    function test_Mint_ZeroAmountDoesNotChangeSupply() public {
        vm.prank(minter);
        token.mint(alice, 0);

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Mint_MultipleTimes() public {
        vm.startPrank(minter);

        token.mint(alice, 100 ether);
        token.mint(alice, 200 ether);
        token.mint(bob, 300 ether);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), 300 ether);
        assertEq(token.balanceOf(bob), 300 ether);
        assertEq(token.totalSupply(), 600 ether);
    }

    function test_Mint_ToMultipleAccounts() public {
        vm.startPrank(minter);

        token.mint(alice, 100 ether);
        token.mint(bob, 200 ether);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.totalSupply(), 300 ether);
    }

    /*//////////////////////////////////////////////////////////////
                         MINT AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    function test_Mint_RevertsForUnauthorizedCaller() public {
        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(attacker);
        token.mint(alice, MINT_AMOUNT);
    }

    function test_Mint_RevertsForIssuerWhenNotMinter() public {
        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(issuer);
        token.mint(alice, MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                              BURNING
    //////////////////////////////////////////////////////////////*/

    function test_Burn_ReducesBalance() public {
        vm.startPrank(minter);

        token.mint(alice, MINT_AMOUNT);
        token.burn(alice, 40 ether);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), 60 ether);
    }

    function test_Burn_ReducesTotalSupply() public {
        vm.startPrank(minter);

        token.mint(alice, MINT_AMOUNT);
        token.burn(alice, 40 ether);

        vm.stopPrank();

        assertEq(token.totalSupply(), 60 ether);
    }

    function test_Burn_EmitsTokensBurned() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit IInvestmentToken.TokensBurned(alice, 40 ether);

        vm.prank(minter);
        token.burn(alice, 40 ether);
    }

    function test_Burn_EntireBalance() public {
        vm.startPrank(minter);

        token.mint(alice, MINT_AMOUNT);
        token.burn(alice, MINT_AMOUNT);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_Burn_RevertsForInsufficientBalance() public {
        vm.expectRevert(IInvestmentToken.InsufficientBalance.selector);

        vm.prank(minter);
        token.burn(alice, MINT_AMOUNT);
    }

    function test_Burn_RevertsWhenAmountExceedsBalance() public {
        vm.startPrank(minter);

        token.mint(alice, 50 ether);

        vm.expectRevert(IInvestmentToken.InsufficientBalance.selector);
        token.burn(alice, 51 ether);

        vm.stopPrank();
    }

    function test_Burn_RevertsForZeroAddress() public {
        vm.expectRevert(IInvestmentToken.InvalidAddress.selector);

        vm.prank(minter);
        token.burn(address(0), MINT_AMOUNT);
    }

    function test_Burn_ZeroAmountDoesNotChangeBalance() public {
        vm.startPrank(minter);

        token.mint(alice, MINT_AMOUNT);
        token.burn(alice, 0);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), MINT_AMOUNT);
        assertEq(token.totalSupply(), MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                          BURN AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    function test_Burn_RevertsForUnauthorizedCaller() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(attacker);
        token.burn(alice, 10 ether);
    }

    function test_Burn_RevertsForIssuerWhenNotMinter() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(issuer);
        token.burn(alice, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                         MINTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_SetMinter_UpdatesMinter() public {
        vm.prank(minter);
        token.setMinter(newMinter);

        assertEq(token.minter(), newMinter);
    }

    function test_SetMinter_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit IInvestmentToken.MinterUpdated(minter, newMinter);

        vm.prank(minter);
        token.setMinter(newMinter);
    }

    function test_SetMinter_RevertsForZeroAddress() public {
        vm.expectRevert(IInvestmentToken.InvalidAddress.selector);

        vm.prank(minter);
        token.setMinter(address(0));
    }

    function test_SetMinter_RevertsForUnauthorizedCaller() public {
        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(attacker);
        token.setMinter(newMinter);
    }

    function test_OldMinter_LosesMintPermission() public {
        vm.prank(minter);
        token.setMinter(newMinter);

        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
    }

    function test_OldMinter_LosesBurnPermission() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.prank(minter);
        token.setMinter(newMinter);

        vm.expectRevert(IInvestmentToken.Unauthorized.selector);

        vm.prank(minter);
        token.burn(alice, 10 ether);
    }

    function test_NewMinter_GainsMintPermission() public {
        vm.prank(minter);
        token.setMinter(newMinter);

        vm.prank(newMinter);
        token.mint(alice, MINT_AMOUNT);

        assertEq(token.balanceOf(alice), MINT_AMOUNT);
    }

    function test_NewMinter_GainsBurnPermission() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.prank(minter);
        token.setMinter(newMinter);

        vm.prank(newMinter);
        token.burn(alice, 40 ether);

        assertEq(token.balanceOf(alice), 60 ether);
    }

    function test_NewMinter_CanTransferMinterRoleAgain() public {
        address thirdMinter = makeAddr("thirdMinter");

        vm.prank(minter);
        token.setMinter(newMinter);

        vm.prank(newMinter);
        token.setMinter(thirdMinter);

        assertEq(token.minter(), thirdMinter);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC20 TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_MovesTokensBetweenAccounts() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.prank(alice);
        bool success = token.transfer(bob, 40 ether);

        assertTrue(success);
        assertEq(token.balanceOf(alice), 60 ether);
        assertEq(token.balanceOf(bob), 40 ether);
    }

    function test_Transfer_DoesNotChangeTotalSupply() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.prank(alice);
        token.transfer(bob, 40 ether);

        assertEq(token.totalSupply(), MINT_AMOUNT);
    }

    function test_Transfer_EntireBalance() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        vm.prank(alice);
        token.transfer(bob, MINT_AMOUNT);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), MINT_AMOUNT);
        assertEq(token.totalSupply(), MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                         SUPPLY INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function test_Supply_NeverExceedsMaximum() public {
        vm.prank(minter);
        token.mint(alice, MAX_SUPPLY);

        assertLe(token.totalSupply(), token.maxSupply());
    }

    function test_Burn_CreatesRoomForFutureMinting() public {
        vm.startPrank(minter);

        token.mint(alice, MAX_SUPPLY);
        token.burn(alice, 100 ether);
        token.mint(bob, 100 ether);

        vm.stopPrank();

        assertEq(token.totalSupply(), MAX_SUPPLY);
    }

    function test_TotalSupply_EqualsSumOfBalances() public {
        vm.startPrank(minter);

        token.mint(alice, 100 ether);
        token.mint(bob, 200 ether);

        vm.stopPrank();

        assertEq(token.totalSupply(), token.balanceOf(alice) + token.balanceOf(bob));
    }

    /*//////////////////////////////////////////////////////////////
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MintWithinCap(uint256 amount) public {
        amount = bound(amount, 0, MAX_SUPPLY);

        vm.prank(minter);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
        assertLe(token.totalSupply(), MAX_SUPPLY);
    }

    function testFuzz_MultipleMintsWithinCap(uint256 firstAmount, uint256 secondAmount) public {
        firstAmount = bound(firstAmount, 0, MAX_SUPPLY);
        secondAmount = bound(secondAmount, 0, MAX_SUPPLY - firstAmount);

        vm.startPrank(minter);

        token.mint(alice, firstAmount);
        token.mint(bob, secondAmount);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), firstAmount);
        assertEq(token.balanceOf(bob), secondAmount);
        assertEq(token.totalSupply(), firstAmount + secondAmount);
        assertLe(token.totalSupply(), MAX_SUPPLY);
    }

    function testFuzz_BurnNeverExceedsBalance(uint256 amount) public {
        amount = bound(amount, 0, MAX_SUPPLY);

        vm.startPrank(minter);

        token.mint(alice, amount);

        uint256 burnAmount = bound(uint256(0), 0, amount);

        token.burn(alice, burnAmount);

        vm.stopPrank();

        assertEq(token.balanceOf(alice), amount - burnAmount);
        assertEq(token.totalSupply(), amount - burnAmount);
    }

    function testFuzz_TransferPreservesSupply(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 0, MAX_SUPPLY);
        transferAmount = bound(transferAmount, 0, mintAmount);

        vm.prank(minter);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.totalSupply(), mintAmount);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), mintAmount);
    }
}
