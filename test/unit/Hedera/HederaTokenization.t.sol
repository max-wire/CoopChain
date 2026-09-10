// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HederaTokenization} from "../../../src/sponsors/Hedera/HederaTokenization.sol";
import {IHederaTokenization} from "../../../src/sponsors/Hedera/interfaces/IHederaTokenization.sol";

contract HederaTokenizationTest is Test {
    HederaTokenization public hedera;

    address owner = address(0x123);
    address attacker = address(0x456);

    uint256 investmentId = 1;

    string securityAddress = "0.0.7708432";

    function setUp() public {
        vm.prank(owner);
        hedera = new HederaTokenization();
    }

    function test_ConstructorSetsOwner() public view {
        assertEq(hedera.owner(), owner);
    }

    function test_RegisterAsset() public {
        vm.prank(owner);

        hedera.registerAsset(investmentId, securityAddress, "CoopChain Real Estate Fund", "CCREF");

        IHederaTokenization.HederaAsset memory asset = hedera.getAsset(investmentId);

        assertEq(asset.investmentId, investmentId);
        assertEq(asset.securityAddress, securityAddress);
        assertEq(asset.name, "CoopChain Real Estate Fund");
        assertEq(asset.symbol, "CCREF");
        assertGt(asset.createdAt, 0);
        assertTrue(asset.active);

        assertTrue(hedera.isRegistered(investmentId));
    }

    function test_RevertWhenUnauthorizedRegistersAsset() public {
        vm.prank(attacker);

        vm.expectRevert(HederaTokenization.Unauthorized.selector);

        hedera.registerAsset(investmentId, securityAddress, "CoopChain Real Estate Fund", "CCREF");
    }

    function test_RevertWhenInvestmentIdIsZero() public {
        vm.prank(owner);

        vm.expectRevert(HederaTokenization.InvalidInvestmentId.selector);

        hedera.registerAsset(0, securityAddress, "CoopChain Real Estate Fund", "CCREF");
    }

    function test_RevertWhenSecurityAddressIsEmpty() public {
        vm.prank(owner);

        vm.expectRevert(HederaTokenization.InvalidSecurityAddress.selector);

        hedera.registerAsset(investmentId, "", "CoopChain Real Estate Fund", "CCREF");
    }

    function test_RevertWhenAssetAlreadyRegistered() public {
        vm.startPrank(owner);

        hedera.registerAsset(investmentId, securityAddress, "CoopChain Real Estate Fund", "CCREF");

        vm.expectRevert(HederaTokenization.AssetAlreadyRegistered.selector);

        hedera.registerAsset(investmentId, securityAddress, "CoopChain Real Estate Fund", "CCREF");

        vm.stopPrank();
    }

    function test_DeactivateAsset() public {
        vm.startPrank(owner);

        hedera.registerAsset(investmentId, securityAddress, "CoopChain Real Estate Fund", "CCREF");

        hedera.deactivateAsset(investmentId);

        vm.stopPrank();

        IHederaTokenization.HederaAsset memory asset = hedera.getAsset(investmentId);

        assertFalse(asset.active);
    }

    function test_RevertWhenDeactivatingUnknownAsset() public {
        vm.prank(owner);

        vm.expectRevert(HederaTokenization.AssetNotRegistered.selector);

        hedera.deactivateAsset(999);
    }

    function test_IsRegisteredReturnsFalseInitially() public view {
        assertFalse(hedera.isRegistered(investmentId));
    }
}
