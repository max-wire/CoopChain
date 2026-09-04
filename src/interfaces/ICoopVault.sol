// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICoopVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error MemberAlreadyExists();
    error MemberNotFound();
    error MemberInactive();
    error NationalIdAlreadyRegistered();
    error InvalidNationalIdHash();
    error NotOwner();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event MemberRegistered(uint256 indexed memberId, address indexed wallet, uint256 joinedAt);

    event MemberDeactivated(uint256 indexed memberId, address indexed wallet);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Member {
        uint256 memberId;
        address wallet;
        bytes32 nationalIdHash;
        uint256 joinedAt;
        bool active;
    }

    /*//////////////////////////////////////////////////////////////
                        MEMBER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new cooperative member.
    /// @param nationalIdHash Hash of the member's national ID.
    function registerMember(bytes32 nationalIdHash) external;

    /// @notice Deactivates an existing member.
    /// @param wallet Address of the member to deactivate.
    function deactivateMember(address wallet) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true if the wallet belongs to a registered member.
    function isMember(address wallet) external view returns (bool);

    /// @notice Returns true if the member is currently active.
    function isActiveMember(address wallet) external view returns (bool);

    /// @notice Returns member information by wallet address.
    function getMember(address wallet) external view returns (Member memory);

    /// @notice Returns member information by member ID.
    function getMemberById(uint256 memberId) external view returns (Member memory);

    /// @notice Returns the total number of active members.
    function totalMembers() external view returns (uint256);

    /// @notice Returns the list of all registered member wallets.
    function getMemberWallets() external view returns (address[] memory);

    /// @notice Returns the contract owner.
    function owner() external view returns (address);

    /// @notice Returns the next member ID that will be assigned.
    function nextMemberId() external view returns (uint256);
}
