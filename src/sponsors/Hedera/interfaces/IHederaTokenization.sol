// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IHederaTokenization
/// @notice Interface for registering and managing tokenized investment assets
///         issued or represented through the Hedera Asset Tokenization Service.
/// @dev Implementations are responsible for maintaining the relationship between
///      a CoopChain investment ID and its corresponding Hedera security/token.
///
///      The interface intentionally stores the Hedera security address as a
///      string because the external Hedera asset identifier may use formats
///      such as a Hedera token ID (e.g. "0.0.123456") rather than an EVM address.
interface IHederaTokenization {
    /// @notice Represents a registered Hedera tokenized investment asset.
    /// @dev An asset is uniquely identified within the implementation by
    ///      `investmentId`.
    struct HederaAsset {
        /// @notice CoopChain investment identifier associated with the Hedera asset.
        uint256 investmentId;

        /// @notice Hedera security/token identifier associated with the investment.
        /// @dev Typically represented as a Hedera token ID string.
        string securityAddress;

        /// @notice Human-readable name of the tokenized security.
        string name;

        /// @notice Symbol of the tokenized security.
        string symbol;

        /// @notice Unix timestamp at which the asset was registered.
        uint256 createdAt;

        /// @notice Indicates whether the asset is currently active.
        /// @dev Deactivation should set this value to false without deleting
        ///      the historical asset record.
        bool active;
    }

    /// @notice Registers a Hedera asset for a CoopChain investment.
    /// @dev Implementations should associate the supplied Hedera security
    ///      identifier with `investmentId`.
    ///
    ///      The implementation should define whether an existing registration
    ///      may be overwritten or whether duplicate registrations are rejected.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    /// @param securityAddress Hedera security/token identifier.
    /// @param name Human-readable name of the tokenized investment.
    /// @param symbol Symbol representing the tokenized investment.
    function registerAsset(
        uint256 investmentId,
        string calldata securityAddress,
        string calldata name,
        string calldata symbol
    ) external;

    /// @notice Deactivates a previously registered Hedera asset.
    /// @dev Deactivation should preserve the asset's historical registration
    ///      data while marking the asset as inactive.
    ///
    ///      Implementations should revert if the specified investment has not
    ///      been registered.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    function deactivateAsset(uint256 investmentId) external;

    /// @notice Returns the Hedera asset registered for an investment.
    /// @dev Implementations should revert or return an empty/default struct
    ///      when the investment has not been registered, according to the
    ///      implementation's documented behavior.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    /// @return asset The Hedera asset associated with the investment.
    function getAsset(uint256 investmentId) external view returns (HederaAsset memory asset);

    /// @notice Checks whether an investment has a registered Hedera asset.
    /// @dev Registration status is distinct from the asset's `active` status.
    ///      A registered asset may exist while being inactive.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    /// @return registered True if an asset has been registered for the investment.
    function isRegistered(uint256 investmentId) external view returns (bool registered);
}
