// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {InvestmentRegistry} from "../../src/Investment/InvestmentRegistry.sol";
import {IInvestmentRegistry} from "../../src/interfaces/IInvestmentRegistry.sol";

contract InvestmentRegistryTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    InvestmentRegistry internal registry;

    address internal admin;
    address internal unauthorizedUser;
    address internal issuer;
    address internal token;

    string internal constant INVESTMENT_NAME = "Coop Equity Fund";
    string internal constant INVESTMENT_SYMBOL = "COOP-EQ";

    uint256 internal constant INITIAL_PRICE = 100e6;
    uint256 internal constant INITIAL_SUPPLY = 1_000_000;

    uint256 internal constant UPDATED_PRICE = 125e6;
    uint256 internal constant UPDATED_SUPPLY = 2_000_000;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        admin = makeAddr("admin");
        unauthorizedUser = makeAddr("unauthorizedUser");
        issuer = makeAddr("issuer");
        token = makeAddr("token");

        vm.prank(admin);
        registry = new InvestmentRegistry();
    }

    /*//////////////////////////////////////////////////////////////
                         CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateInvestment_CreatesInvestment() public {
        uint256 investmentId = _createInvestment();

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.id, 1);
        assertEq(investment.name, INVESTMENT_NAME);
        assertEq(investment.symbol, INVESTMENT_SYMBOL);
        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.EQUITY));
        assertEq(investment.token, token);
        assertEq(investment.issuer, issuer);
        assertEq(investment.price, INITIAL_PRICE);
        assertEq(investment.totalSupply, INITIAL_SUPPLY);
        assertTrue(investment.active);
    }

    function test_CreateInvestment_ReturnsSequentialIds() public {
        vm.startPrank(admin);

        uint256 firstId = registry.createInvestment(
            "Investment One", "INV1", IInvestmentRegistry.AssetType.EQUITY, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        uint256 secondId = registry.createInvestment(
            "Investment Two", "INV2", IInvestmentRegistry.AssetType.BOND, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        uint256 thirdId = registry.createInvestment(
            "Investment Three", "INV3", IInvestmentRegistry.AssetType.FUND, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        vm.stopPrank();

        assertEq(firstId, 1);
        assertEq(secondId, 2);
        assertEq(thirdId, 3);
    }

    function test_CreateInvestment_IncrementsCount() public {
        assertEq(registry.getInvestmentCount(), 0);

        _createInvestment();

        assertEq(registry.getInvestmentCount(), 1);

        _createInvestmentWithDetails(
            "Second Investment", "INV2", IInvestmentRegistry.AssetType.BOND, token, issuer, 200e6, 500_000
        );

        assertEq(registry.getInvestmentCount(), 2);
    }

    function test_CreateInvestment_AddsIdToInvestmentIds() public {
        _createInvestment();

        _createInvestmentWithDetails(
            "Second Investment", "INV2", IInvestmentRegistry.AssetType.BOND, token, issuer, 200e6, 500_000
        );

        uint256[] memory investmentIds = registry.getInvestmentIds();

        assertEq(investmentIds.length, 2);
        assertEq(investmentIds[0], 1);
        assertEq(investmentIds[1], 2);
    }

    function test_CreateInvestment_IsActiveByDefault() public {
        uint256 investmentId = _createInvestment();

        assertTrue(registry.isInvestmentActive(investmentId));
    }

    function test_CreateInvestment_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);

        emit IInvestmentRegistry.InvestmentCreated(
            1,
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.EQUITY,
            issuer,
            token,
            INITIAL_PRICE,
            INITIAL_SUPPLY
        );

        vm.prank(admin);
        registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.EQUITY,
            token,
            issuer,
            INITIAL_PRICE,
            INITIAL_SUPPLY
        );
    }

    /*//////////////////////////////////////////////////////////////
                       ASSET TYPE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateInvestment_AllAssetTypes() public {
        vm.startPrank(admin);

        uint256 equityId = registry.createInvestment(
            "Equity", "EQ", IInvestmentRegistry.AssetType.EQUITY, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        uint256 bondId = registry.createInvestment(
            "Bond", "BOND", IInvestmentRegistry.AssetType.BOND, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        uint256 fundId = registry.createInvestment(
            "Fund", "FUND", IInvestmentRegistry.AssetType.FUND, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        uint256 realEstateId = registry.createInvestment(
            "Real Estate", "RE", IInvestmentRegistry.AssetType.REAL_ESTATE, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        uint256 receivableId = registry.createInvestment(
            "Receivable", "REC", IInvestmentRegistry.AssetType.RECEIVABLE, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );

        vm.stopPrank();

        assertEq(uint256(registry.getInvestment(equityId).assetType), uint256(IInvestmentRegistry.AssetType.EQUITY));

        assertEq(uint256(registry.getInvestment(bondId).assetType), uint256(IInvestmentRegistry.AssetType.BOND));

        assertEq(uint256(registry.getInvestment(fundId).assetType), uint256(IInvestmentRegistry.AssetType.FUND));

        assertEq(
            uint256(registry.getInvestment(realEstateId).assetType), uint256(IInvestmentRegistry.AssetType.REAL_ESTATE)
        );

        assertEq(
            uint256(registry.getInvestment(receivableId).assetType), uint256(IInvestmentRegistry.AssetType.RECEIVABLE)
        );
    }

    /*//////////////////////////////////////////////////////////////
                       CREATION VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_NameIsEmpty() public {
        vm.expectRevert(IInvestmentRegistry.InvalidName.selector);

        vm.prank(admin);
        registry.createInvestment(
            "", INVESTMENT_SYMBOL, IInvestmentRegistry.AssetType.EQUITY, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );
    }

    function test_RevertWhen_SymbolIsEmpty() public {
        vm.expectRevert(IInvestmentRegistry.InvalidSymbol.selector);

        vm.prank(admin);
        registry.createInvestment(
            INVESTMENT_NAME, "", IInvestmentRegistry.AssetType.EQUITY, token, issuer, INITIAL_PRICE, INITIAL_SUPPLY
        );
    }

    function test_RevertWhen_TokenIsZeroAddress() public {
        vm.expectRevert(IInvestmentRegistry.InvalidAddress.selector);

        vm.prank(admin);
        registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.EQUITY,
            address(0),
            issuer,
            INITIAL_PRICE,
            INITIAL_SUPPLY
        );
    }

    function test_RevertWhen_IssuerIsZeroAddress() public {
        vm.expectRevert(IInvestmentRegistry.InvalidAddress.selector);

        vm.prank(admin);
        registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.EQUITY,
            token,
            address(0),
            INITIAL_PRICE,
            INITIAL_SUPPLY
        );
    }

    function test_RevertWhen_PriceIsZero() public {
        vm.expectRevert(IInvestmentRegistry.InvalidPrice.selector);

        vm.prank(admin);
        registry.createInvestment(
            INVESTMENT_NAME, INVESTMENT_SYMBOL, IInvestmentRegistry.AssetType.EQUITY, token, issuer, 0, INITIAL_SUPPLY
        );
    }

    function test_RevertWhen_TotalSupplyIsZero() public {
        vm.expectRevert(IInvestmentRegistry.InvalidSupply.selector);

        vm.prank(admin);
        registry.createInvestment(
            INVESTMENT_NAME, INVESTMENT_SYMBOL, IInvestmentRegistry.AssetType.EQUITY, token, issuer, INITIAL_PRICE, 0
        );
    }

    function testFuzz_CreateInvestment_ValidParameters(
        string memory name,
        string memory symbol,
        uint8 assetType,
        uint256 price,
        uint256 totalSupply
    ) public {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(price > 0);
        vm.assume(totalSupply > 0);
        vm.assume(assetType < 5);

        vm.prank(admin);

        uint256 investmentId = registry.createInvestment(
            name, symbol, IInvestmentRegistry.AssetType(assetType), token, issuer, price, totalSupply
        );

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.id, investmentId);
        assertEq(investment.name, name);
        assertEq(investment.symbol, symbol);
        assertEq(uint256(investment.assetType), assetType);
        assertEq(investment.token, token);
        assertEq(investment.issuer, issuer);
        assertEq(investment.price, price);
        assertEq(investment.totalSupply, totalSupply);
        assertTrue(investment.active);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UpdateInvestment_UpdatesPrice() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.updateInvestment(investmentId, UPDATED_PRICE, INITIAL_SUPPLY);

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.price, UPDATED_PRICE);
        assertEq(investment.totalSupply, INITIAL_SUPPLY);
    }

    function test_UpdateInvestment_UpdatesSupply() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.updateInvestment(investmentId, INITIAL_PRICE, UPDATED_SUPPLY);

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.price, INITIAL_PRICE);
        assertEq(investment.totalSupply, UPDATED_SUPPLY);
    }

    function test_UpdateInvestment_UpdatesBothPriceAndSupply() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.updateInvestment(investmentId, UPDATED_PRICE, UPDATED_SUPPLY);

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.price, UPDATED_PRICE);
        assertEq(investment.totalSupply, UPDATED_SUPPLY);
        assertTrue(investment.active);
    }

    function test_UpdateInvestment_PreservesMetadata() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.updateInvestment(investmentId, UPDATED_PRICE, UPDATED_SUPPLY);

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.id, investmentId);
        assertEq(investment.name, INVESTMENT_NAME);
        assertEq(investment.symbol, INVESTMENT_SYMBOL);
        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.EQUITY));
        assertEq(investment.token, token);
        assertEq(investment.issuer, issuer);
        assertTrue(investment.active);
    }

    function test_UpdateInvestment_EmitsEvent() public {
        uint256 investmentId = _createInvestment();

        vm.expectEmit(true, false, false, true);

        emit IInvestmentRegistry.InvestmentUpdated(investmentId, UPDATED_PRICE, UPDATED_SUPPLY, true);

        vm.prank(admin);
        registry.updateInvestment(investmentId, UPDATED_PRICE, UPDATED_SUPPLY);
    }

    function test_RevertWhen_UpdatingNonexistentInvestment() public {
        vm.expectRevert(IInvestmentRegistry.InvestmentNotFound.selector);

        vm.prank(admin);
        registry.updateInvestment(1, UPDATED_PRICE, UPDATED_SUPPLY);
    }

    function test_RevertWhen_UpdatingInactiveInvestment() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.deactivateInvestment(investmentId);

        vm.expectRevert(IInvestmentRegistry.InvestmentInactive.selector);

        vm.prank(admin);
        registry.updateInvestment(investmentId, UPDATED_PRICE, UPDATED_SUPPLY);
    }

    function test_RevertWhen_UpdatingWithZeroPrice() public {
        uint256 investmentId = _createInvestment();

        vm.expectRevert(IInvestmentRegistry.InvalidPrice.selector);

        vm.prank(admin);
        registry.updateInvestment(investmentId, 0, UPDATED_SUPPLY);
    }

    function test_RevertWhen_UpdatingWithZeroSupply() public {
        uint256 investmentId = _createInvestment();

        vm.expectRevert(IInvestmentRegistry.InvalidSupply.selector);

        vm.prank(admin);
        registry.updateInvestment(investmentId, UPDATED_PRICE, 0);
    }

    /*//////////////////////////////////////////////////////////////
                       DEACTIVATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeactivateInvestment_SetsActiveFalse() public {
        uint256 investmentId = _createInvestment();

        assertTrue(registry.isInvestmentActive(investmentId));

        vm.prank(admin);
        registry.deactivateInvestment(investmentId);

        assertFalse(registry.isInvestmentActive(investmentId));

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertFalse(investment.active);
    }

    function test_DeactivateInvestment_EmitsEvent() public {
        uint256 investmentId = _createInvestment();

        vm.expectEmit(true, false, false, true);

        emit IInvestmentRegistry.InvestmentDeactivated(investmentId);

        vm.prank(admin);
        registry.deactivateInvestment(investmentId);
    }

    function test_RevertWhen_DeactivatingNonexistentInvestment() public {
        vm.expectRevert(IInvestmentRegistry.InvestmentNotFound.selector);

        vm.prank(admin);
        registry.deactivateInvestment(1);
    }

    function test_RevertWhen_DeactivatingAlreadyInactiveInvestment() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.deactivateInvestment(investmentId);

        vm.expectRevert(IInvestmentRegistry.InvestmentAlreadyInactive.selector);

        vm.prank(admin);
        registry.deactivateInvestment(investmentId);
    }

    /*//////////////////////////////////////////////////////////////
                       ADMIN AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsDeployerAsAdmin() public view {
        assertEq(registry.getAdmin(), admin);
    }

    function test_RevertWhen_UnauthorizedUserCreatesInvestment() public {
        vm.expectRevert(IInvestmentRegistry.Unauthorized.selector);

        vm.prank(unauthorizedUser);
        registry.createInvestment(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.EQUITY,
            token,
            issuer,
            INITIAL_PRICE,
            INITIAL_SUPPLY
        );
    }

    function test_RevertWhen_UnauthorizedUserUpdatesInvestment() public {
        uint256 investmentId = _createInvestment();

        vm.expectRevert(IInvestmentRegistry.Unauthorized.selector);

        vm.prank(unauthorizedUser);
        registry.updateInvestment(investmentId, UPDATED_PRICE, UPDATED_SUPPLY);
    }

    function test_RevertWhen_UnauthorizedUserDeactivatesInvestment() public {
        uint256 investmentId = _createInvestment();

        vm.expectRevert(IInvestmentRegistry.Unauthorized.selector);

        vm.prank(unauthorizedUser);
        registry.deactivateInvestment(investmentId);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetInvestment_ReturnsCorrectInvestment() public {
        uint256 investmentId = _createInvestment();

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.id, investmentId);
        assertEq(investment.name, INVESTMENT_NAME);
        assertEq(investment.symbol, INVESTMENT_SYMBOL);
        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.EQUITY));
        assertEq(investment.token, token);
        assertEq(investment.issuer, issuer);
        assertEq(investment.price, INITIAL_PRICE);
        assertEq(investment.totalSupply, INITIAL_SUPPLY);
        assertTrue(investment.active);
    }

    function test_RevertWhen_GetInvestmentDoesNotExist() public {
        vm.expectRevert(IInvestmentRegistry.InvestmentNotFound.selector);

        registry.getInvestment(1);
    }

    function test_GetInvestmentCount_ReturnsZeroInitially() public view {
        assertEq(registry.getInvestmentCount(), 0);
    }

    function test_GetInvestmentCount_ReturnsCorrectCount() public {
        _createInvestment();

        assertEq(registry.getInvestmentCount(), 1);

        _createInvestmentWithDetails(
            "Second Investment", "INV2", IInvestmentRegistry.AssetType.BOND, token, issuer, 200e6, 500_000
        );

        assertEq(registry.getInvestmentCount(), 2);

        _createInvestmentWithDetails(
            "Third Investment", "INV3", IInvestmentRegistry.AssetType.FUND, token, issuer, 300e6, 250_000
        );

        assertEq(registry.getInvestmentCount(), 3);
    }

    function test_GetInvestmentIds_ReturnsEmptyInitially() public view {
        uint256[] memory investmentIds = registry.getInvestmentIds();

        assertEq(investmentIds.length, 0);
    }

    function test_GetInvestmentIds_ReturnsAllIds() public {
        _createInvestment();

        _createInvestmentWithDetails("Bond", "BOND", IInvestmentRegistry.AssetType.BOND, token, issuer, 200e6, 500_000);

        _createInvestmentWithDetails("Fund", "FUND", IInvestmentRegistry.AssetType.FUND, token, issuer, 300e6, 250_000);

        uint256[] memory investmentIds = registry.getInvestmentIds();

        assertEq(investmentIds.length, 3);
        assertEq(investmentIds[0], 1);
        assertEq(investmentIds[1], 2);
        assertEq(investmentIds[2], 3);
    }

    function test_IsInvestmentActive_ReturnsTrueForActiveInvestment() public {
        uint256 investmentId = _createInvestment();

        assertTrue(registry.isInvestmentActive(investmentId));
    }

    function test_IsInvestmentActive_ReturnsFalseForInactiveInvestment() public {
        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.deactivateInvestment(investmentId);

        assertFalse(registry.isInvestmentActive(investmentId));
    }

    function test_IsInvestmentActive_ReturnsFalseForNonexistentInvestment() public view {
        assertFalse(registry.isInvestmentActive(999));
    }

    /*//////////////////////////////////////////////////////////////
                      MULTIPLE INVESTMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleInvestments_AreIndependent() public {
        uint256 firstId = _createInvestment();

        uint256 secondId = _createInvestmentWithDetails(
            "Coop Bond",
            "COOP-BOND",
            IInvestmentRegistry.AssetType.BOND,
            makeAddr("bondToken"),
            makeAddr("bondIssuer"),
            500e6,
            750_000
        );

        vm.prank(admin);
        registry.updateInvestment(firstId, 150e6, 900_000);

        IInvestmentRegistry.Investment memory first = registry.getInvestment(firstId);

        IInvestmentRegistry.Investment memory second = registry.getInvestment(secondId);

        assertEq(first.price, 150e6);
        assertEq(first.totalSupply, 900_000);

        assertEq(second.name, "Coop Bond");
        assertEq(second.symbol, "COOP-BOND");
        assertEq(second.price, 500e6);
        assertEq(second.totalSupply, 750_000);
    }

    function test_DeactivatingOneInvestment_DoesNotAffectAnother() public {
        uint256 firstId = _createInvestment();

        uint256 secondId = _createInvestmentWithDetails(
            "Coop Bond",
            "COOP-BOND",
            IInvestmentRegistry.AssetType.BOND,
            makeAddr("bondToken"),
            makeAddr("bondIssuer"),
            500e6,
            750_000
        );

        vm.prank(admin);
        registry.deactivateInvestment(firstId);

        assertFalse(registry.isInvestmentActive(firstId));
        assertTrue(registry.isInvestmentActive(secondId));
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_UpdateInvestment(uint256 price, uint256 totalSupply) public {
        vm.assume(price > 0);
        vm.assume(totalSupply > 0);

        uint256 investmentId = _createInvestment();

        vm.prank(admin);
        registry.updateInvestment(investmentId, price, totalSupply);

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.price, price);
        assertEq(investment.totalSupply, totalSupply);
        assertTrue(investment.active);
    }

    function testFuzz_CreateInvestment_PreservesValues(uint256 price, uint256 totalSupply) public {
        vm.assume(price > 0);
        vm.assume(totalSupply > 0);

        uint256 investmentId = _createInvestmentWithDetails(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.REAL_ESTATE,
            token,
            issuer,
            price,
            totalSupply
        );

        IInvestmentRegistry.Investment memory investment = registry.getInvestment(investmentId);

        assertEq(investment.price, price);
        assertEq(investment.totalSupply, totalSupply);
        assertEq(uint256(investment.assetType), uint256(IInvestmentRegistry.AssetType.REAL_ESTATE));
        assertTrue(investment.active);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createInvestment() internal returns (uint256 investmentId) {
        return _createInvestmentWithDetails(
            INVESTMENT_NAME,
            INVESTMENT_SYMBOL,
            IInvestmentRegistry.AssetType.EQUITY,
            token,
            issuer,
            INITIAL_PRICE,
            INITIAL_SUPPLY
        );
    }

    function _createInvestmentWithDetails(
        string memory name,
        string memory symbol,
        IInvestmentRegistry.AssetType assetType,
        address investmentToken,
        address investmentIssuer,
        uint256 price,
        uint256 totalSupply
    ) internal returns (uint256 investmentId) {
        vm.prank(admin);

        investmentId =
            registry.createInvestment(name, symbol, assetType, investmentToken, investmentIssuer, price, totalSupply);
    }
}
