// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {CoopVault} from "../../src/CoopVault.sol";
import {ICoopVault} from "../../src/interfaces/ICoopVault.sol";

contract CoopVaultTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    CoopVault internal vault;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie");

    bytes32 internal aliceNationalId = keccak256("alice-national-id");

    bytes32 internal bobNationalId = keccak256("bob-national-id");

    bytes32 internal charlieNationalId = keccak256("charlie-national-id");

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MemberRegistered(uint256 indexed memberId, address indexed wallet, uint256 joinedAt);

    event MemberDeactivated(uint256 indexed memberId, address indexed wallet);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.prank(owner);
        vault = new CoopVault();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIAL STATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(vault.owner(), owner);
        assertEq(vault.nextMemberId(), 1);
        assertEq(vault.totalMembers(), 0);

        address[] memory wallets = vault.getMemberWallets();

        assertEq(wallets.length, 0);

        assertFalse(vault.isMember(alice));
        assertFalse(vault.isActiveMember(alice));
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RegisterMember() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        ICoopVault.Member memory member = vault.getMember(alice);

        assertEq(member.memberId, 1);
        assertEq(member.wallet, alice);
        assertEq(member.nationalIdHash, aliceNationalId);
        assertEq(member.joinedAt, block.timestamp);
        assertTrue(member.active);
    }

    function test_RegisterMember_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);

        emit MemberRegistered(1, alice, block.timestamp);

        vm.prank(alice);
        vault.registerMember(aliceNationalId);
    }

    function test_RegisterMember_IncrementsMemberId() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        assertEq(vault.getMember(alice).memberId, 1);

        assertEq(vault.getMember(bob).memberId, 2);

        assertEq(vault.nextMemberId(), 3);
    }

    function test_RegisterMember_IncrementsTotalMembers() public {
        assertEq(vault.totalMembers(), 0);

        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        assertEq(vault.totalMembers(), 1);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        assertEq(vault.totalMembers(), 2);
    }

    function test_RegisterMember_AddsWalletToMemberList() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        address[] memory wallets = vault.getMemberWallets();

        assertEq(wallets.length, 2);
        assertEq(wallets[0], alice);
        assertEq(wallets[1], bob);
    }

    function test_RegisterMember_SetsJoinedAt() public {
        uint256 timestamp = 1_000_000;

        vm.warp(timestamp);

        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        assertEq(vault.getMember(alice).joinedAt, timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                    REGISTRATION REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertRegisterMember_AlreadyExists() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.expectRevert(ICoopVault.MemberAlreadyExists.selector);

        vm.prank(alice);
        vault.registerMember(bobNationalId);
    }

    function test_RevertRegisterMember_InvalidNationalIdHash() public {
        vm.expectRevert(ICoopVault.InvalidNationalIdHash.selector);

        vm.prank(alice);
        vault.registerMember(bytes32(0));
    }

    function test_RevertRegisterMember_NationalIdAlreadyRegistered() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.expectRevert(ICoopVault.NationalIdAlreadyRegistered.selector);

        vm.prank(bob);
        vault.registerMember(aliceNationalId);
    }

    /*//////////////////////////////////////////////////////////////
                        MEMBER VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IsMember() public {
        assertFalse(vault.isMember(alice));

        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        assertTrue(vault.isMember(alice));
    }

    function test_IsActiveMember() public {
        assertFalse(vault.isActiveMember(alice));

        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        assertTrue(vault.isActiveMember(alice));
    }

    function test_GetMember() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        ICoopVault.Member memory member = vault.getMember(alice);

        assertEq(member.memberId, 1);
        assertEq(member.wallet, alice);
        assertEq(member.nationalIdHash, aliceNationalId);
        assertEq(member.joinedAt, block.timestamp);
        assertTrue(member.active);
    }

    function test_GetMemberById() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        ICoopVault.Member memory member = vault.getMemberById(1);

        assertEq(member.memberId, 1);
        assertEq(member.wallet, alice);
        assertEq(member.nationalIdHash, aliceNationalId);
        assertTrue(member.active);
    }

    function test_GetMemberById_MultipleMembers() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        vm.prank(charlie);
        vault.registerMember(charlieNationalId);

        assertEq(vault.getMemberById(1).wallet, alice);

        assertEq(vault.getMemberById(2).wallet, bob);

        assertEq(vault.getMemberById(3).wallet, charlie);
    }

    function test_GetMemberWallets_EmptyInitially() public view {
        address[] memory wallets = vault.getMemberWallets();

        assertEq(wallets.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    MEMBER VIEW REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertGetMember_MemberNotFound() public {
        vm.expectRevert(ICoopVault.MemberNotFound.selector);

        vault.getMember(alice);
    }

    function test_RevertGetMemberById_MemberNotFound() public {
        vm.expectRevert(ICoopVault.MemberNotFound.selector);

        vault.getMemberById(1);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Owner() public view {
        assertEq(vault.owner(), owner);
    }

    function test_NextMemberId_StartsAtOne() public view {
        assertEq(vault.nextMemberId(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    DEACTIVATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeactivateMember() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        assertTrue(vault.isMember(alice));
        assertTrue(vault.isActiveMember(alice));
        assertEq(vault.totalMembers(), 1);

        vm.prank(owner);
        vault.deactivateMember(alice);

        assertTrue(vault.isMember(alice));
        assertFalse(vault.isActiveMember(alice));
        assertEq(vault.totalMembers(), 0);
    }

    function test_DeactivateMember_EmitsEvent() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.expectEmit(true, true, false, true);

        emit MemberDeactivated(1, alice);

        vm.prank(owner);
        vault.deactivateMember(alice);
    }

    function test_DeactivateMember_PreservesMemberData() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(owner);
        vault.deactivateMember(alice);

        ICoopVault.Member memory member = vault.getMember(alice);

        assertEq(member.memberId, 1);
        assertEq(member.wallet, alice);
        assertEq(member.nationalIdHash, aliceNationalId);
        assertEq(member.joinedAt, block.timestamp);
        assertFalse(member.active);
    }

    function test_DeactivateMember_DoesNotRemoveWalletFromList() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(owner);
        vault.deactivateMember(alice);

        address[] memory wallets = vault.getMemberWallets();

        assertEq(wallets.length, 1);
        assertEq(wallets[0], alice);
    }

    /*//////////////////////////////////////////////////////////////
                    DEACTIVATION REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertDeactivateMember_NotOwner() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.expectRevert(ICoopVault.NotOwner.selector);

        vm.prank(alice);
        vault.deactivateMember(alice);
    }

    function test_RevertDeactivateMember_MemberNotFound() public {
        vm.expectRevert(ICoopVault.MemberNotFound.selector);

        vm.prank(owner);
        vault.deactivateMember(alice);
    }

    function test_RevertDeactivateMember_AlreadyInactive() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(owner);
        vault.deactivateMember(alice);

        vm.expectRevert(ICoopVault.MemberInactive.selector);

        vm.prank(owner);
        vault.deactivateMember(alice);
    }

    /*//////////////////////////////////////////////////////////////
                    ACTIVE MEMBER ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function test_TotalMembers_TracksActiveMembers() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        vm.prank(charlie);
        vault.registerMember(charlieNationalId);

        assertEq(vault.totalMembers(), 3);

        vm.prank(owner);
        vault.deactivateMember(bob);

        assertEq(vault.totalMembers(), 2);

        assertTrue(vault.isActiveMember(alice));
        assertFalse(vault.isActiveMember(bob));
        assertTrue(vault.isActiveMember(charlie));
    }

    function test_DeactivateOneMember_DoesNotAffectOthers() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        vm.prank(owner);
        vault.deactivateMember(alice);

        assertFalse(vault.isActiveMember(alice));
        assertTrue(vault.isActiveMember(bob));

        assertEq(vault.getMember(alice).memberId, 1);

        assertEq(vault.getMember(bob).memberId, 2);

        assertEq(vault.totalMembers(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-MEMBER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleMembersRemainIndependent() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        vm.prank(charlie);
        vault.registerMember(charlieNationalId);

        assertTrue(vault.isMember(alice));
        assertTrue(vault.isMember(bob));
        assertTrue(vault.isMember(charlie));

        assertTrue(vault.isActiveMember(alice));
        assertTrue(vault.isActiveMember(bob));
        assertTrue(vault.isActiveMember(charlie));

        assertEq(vault.totalMembers(), 3);
        assertEq(vault.nextMemberId(), 4);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RegisterMember(address wallet, bytes32 nationalIdHash) public {
        vm.assume(wallet != address(0));
        vm.assume(nationalIdHash != bytes32(0));

        vm.prank(wallet);
        vault.registerMember(nationalIdHash);

        ICoopVault.Member memory member = vault.getMember(wallet);

        assertEq(member.memberId, 1);
        assertEq(member.wallet, wallet);
        assertEq(member.nationalIdHash, nationalIdHash);
        assertTrue(member.active);

        assertTrue(vault.isMember(wallet));
        assertTrue(vault.isActiveMember(wallet));

        assertEq(vault.totalMembers(), 1);
        assertEq(vault.nextMemberId(), 2);
    }

    function testFuzz_RegisterMultipleMembers(address wallet1, address wallet2) public {
        vm.assume(wallet1 != address(0));
        vm.assume(wallet2 != address(0));
        vm.assume(wallet1 != wallet2);

        bytes32 id1 = keccak256(abi.encode(wallet1, "id1"));

        bytes32 id2 = keccak256(abi.encode(wallet2, "id2"));

        vm.prank(wallet1);
        vault.registerMember(id1);

        vm.prank(wallet2);
        vault.registerMember(id2);

        assertEq(vault.totalMembers(), 2);
        assertEq(vault.nextMemberId(), 3);

        assertEq(vault.getMemberById(1).wallet, wallet1);

        assertEq(vault.getMemberById(2).wallet, wallet2);
    }

    /*//////////////////////////////////////////////////////////////
                    MEMBER ID INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function test_MemberIdsAreSequential() public {
        vm.prank(alice);
        vault.registerMember(aliceNationalId);

        vm.prank(bob);
        vault.registerMember(bobNationalId);

        vm.prank(charlie);
        vault.registerMember(charlieNationalId);

        assertEq(vault.getMember(alice).memberId, 1);

        assertEq(vault.getMember(bob).memberId, 2);

        assertEq(vault.getMember(charlie).memberId, 3);

        assertEq(vault.nextMemberId(), 4);
    }
}
