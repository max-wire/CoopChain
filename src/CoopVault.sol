// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICoopVault} from "./interfaces/ICoopVault.sol";

contract CoopVault is ICoopVault {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_nextMemberId;

    uint256 private s_totalMembers;

    mapping(address => Member) private s_members;

    mapping(uint256 => address) private s_memberIdToWallet;

    mapping(bytes32 => address) private s_nationalIdToWallet;

    address[] private s_memberList;

    address private immutable i_owner;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        s_nextMemberId = 1;
        i_owner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICoopVault
    function registerMember(bytes32 nationalIdHash) external override {
        if (s_members[msg.sender].wallet != address(0)) {
            revert MemberAlreadyExists();
        }

        if (nationalIdHash == bytes32(0)) {
            revert InvalidNationalIdHash();
        }

        if (s_nationalIdToWallet[nationalIdHash] != address(0)) {
            revert NationalIdAlreadyRegistered();
        }

        s_memberList.push(msg.sender);

        uint256 memberId = s_nextMemberId;
        uint256 joinedAt = block.timestamp;

        s_members[msg.sender] = Member({
            memberId: memberId, wallet: msg.sender, nationalIdHash: nationalIdHash, joinedAt: joinedAt, active: true
        });

        s_memberIdToWallet[memberId] = msg.sender;
        s_nationalIdToWallet[nationalIdHash] = msg.sender;

        s_nextMemberId++;
        s_totalMembers++;

        emit MemberRegistered(memberId, msg.sender, joinedAt);
    }

    /// @inheritdoc ICoopVault
    function deactivateMember(address wallet) external override onlyOwner {
        if (s_members[wallet].wallet == address(0)) {
            revert MemberNotFound();
        }

        Member storage member = s_members[wallet];

        if (!member.active) {
            revert MemberInactive();
        }

        member.active = false;
        s_totalMembers--;

        emit MemberDeactivated(member.memberId, wallet);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICoopVault
    function isMember(address wallet) public view override returns (bool) {
        return s_members[wallet].wallet != address(0);
    }

    /// @inheritdoc ICoopVault
    function isActiveMember(address wallet) public view override returns (bool) {
        return s_members[wallet].active;
    }

    /// @inheritdoc ICoopVault
    function getMember(address wallet) public view override returns (Member memory) {
        if (s_members[wallet].wallet == address(0)) {
            revert MemberNotFound();
        }

        return s_members[wallet];
    }

    /// @inheritdoc ICoopVault
    function getMemberById(uint256 memberId) public view override returns (Member memory) {
        address wallet = s_memberIdToWallet[memberId];

        if (wallet == address(0)) {
            revert MemberNotFound();
        }

        return s_members[wallet];
    }

    /// @inheritdoc ICoopVault
    function totalMembers() public view override returns (uint256) {
        return s_totalMembers;
    }

    /// @inheritdoc ICoopVault
    function getMemberWallets() public view override returns (address[] memory) {
        return s_memberList;
    }

    /// @inheritdoc ICoopVault
    function owner() public view override returns (address) {
        return i_owner;
    }

    /// @inheritdoc ICoopVault
    function nextMemberId() public view override returns (uint256) {
        return s_nextMemberId;
    }
}
