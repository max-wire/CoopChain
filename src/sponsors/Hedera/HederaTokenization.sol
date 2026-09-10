/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHederaTokenization} from "./interfaces/IHederaTokenization.sol";

/// @title HederaTokenization
/// @notice Registry for linking CoopChain investments to securities issued
///         through the Hedera Asset Tokenization Service (ATS).
/// @dev This contract does not issue, mint, transfer, or manage Hedera tokens
///      directly. The actual Hedera ATS issuance is performed by the external
///      Hedera integration layer, while this contract records the resulting
///      security identifier against its corresponding CoopChain investment.
///
///      Each investment can have at most one registered Hedera asset.
///      Registered assets can be deactivated but are not deleted, preserving
///      the historical association between the investment and its Hedera
///      security.
///
///      Administrative operations are restricted to the contract owner.
contract HederaTokenization is IHederaTokenization {
    /// @notice Address authorized to register and deactivate Hedera assets.
    /// @dev Set once during deployment and cannot be changed.
    address public immutable owner;

    /// @notice Stores registered Hedera assets by CoopChain investment ID.
    /// @dev An asset is considered registered when its `createdAt` value is
    ///      non-zero.
    mapping(uint256 => HederaAsset) private _assets;

    /// @notice Thrown when a caller attempts an owner-only operation without
    ///         being the contract owner.
    error Unauthorized();

    /// @notice Thrown when an invalid investment ID is supplied.
    error InvalidInvestmentId();

    /// @notice Thrown when an empty Hedera security identifier is supplied.
    error InvalidSecurityAddress();

    /// @notice Thrown when an investment already has a registered Hedera asset.
    error AssetAlreadyRegistered();

    /// @notice Thrown when an operation requires a registered asset but none
    ///         exists for the supplied investment.
    error AssetNotRegistered();

    /// @notice Emitted when a Hedera security is registered against an
    ///         investment.
    /// @param investmentId Unique CoopChain investment identifier.
    /// @param securityAddress Hedera security/token identifier.
    /// @param name Human-readable name of the tokenized security.
    /// @param symbol Symbol of the tokenized security.
    event HederaAssetRegistered(uint256 indexed investmentId, string securityAddress, string name, string symbol);

    /// @notice Emitted when a registered Hedera asset is deactivated.
    /// @param investmentId Unique CoopChain investment identifier.
    /// @param securityAddress Hedera security/token identifier associated
    ///        with the investment.
    event HederaAssetDeactivated(uint256 indexed investmentId, string securityAddress);

    /// @notice Restricts execution to the contract owner.
    /// @dev Used for administrative asset registration and deactivation.
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized();
        }

        _;
    }

    /// @notice Initializes the Hedera tokenization registry.
    /// @dev The deploying address becomes the immutable owner and is the only
    ///      address authorized to perform administrative registry operations.
    constructor() {
        owner = msg.sender;
    }

    /// @inheritdoc IHederaTokenization
    /// @notice Registers a Hedera ATS security against a CoopChain investment.
    /// @dev The actual security issuance occurs outside this contract through
    ///      the Hedera integration layer. This function records the resulting
    ///      Hedera security identifier and associated metadata on-chain.
    ///
    ///      An investment can only be registered once. Deactivated assets
    ///      cannot be registered again because their historical record remains
    ///      stored.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    /// @param securityAddress Hedera security/token identifier.
    /// @param name Human-readable name of the tokenized security.
    /// @param symbol Symbol representing the tokenized security.
    ///
    /// @custom:reverts Unauthorized If the caller is not the contract owner.
    /// @custom:reverts InvalidInvestmentId If `investmentId` is zero.
    /// @custom:reverts InvalidSecurityAddress If `securityAddress` is empty.
    /// @custom:reverts AssetAlreadyRegistered If the investment already has
    ///         a registered Hedera asset.
    function registerAsset(
        uint256 investmentId,
        string calldata securityAddress,
        string calldata name,
        string calldata symbol
    ) external onlyOwner {
        if (investmentId == 0) {
            revert InvalidInvestmentId();
        }

        if (bytes(securityAddress).length == 0) {
            revert InvalidSecurityAddress();
        }

        if (_assets[investmentId].createdAt != 0) {
            revert AssetAlreadyRegistered();
        }

        _assets[investmentId] = HederaAsset({
            investmentId: investmentId,
            securityAddress: securityAddress,
            name: name,
            symbol: symbol,
            createdAt: block.timestamp,
            active: true
        });

        emit HederaAssetRegistered(investmentId, securityAddress, name, symbol);
    }

    /// @inheritdoc IHederaTokenization
    /// @notice Deactivates the CoopChain-side association with a Hedera asset.
    /// @dev This function does not destroy, freeze, revoke, or otherwise
    ///      modify the underlying Hedera ATS security.
    ///
    ///      The asset record remains stored so that its historical registration
    ///      and Hedera security identifier can still be retrieved.
    ///
    ///      Calling this function on an already inactive asset is intentionally
    ///      idempotent and performs no state change.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    ///
    /// @custom:reverts Unauthorized If the caller is not the contract owner.
    /// @custom:reverts AssetNotRegistered If no asset has been registered for
    ///         the supplied investment.
    function deactivateAsset(uint256 investmentId) external onlyOwner {
        HederaAsset storage asset = _assets[investmentId];

        if (asset.createdAt == 0) {
            revert AssetNotRegistered();
        }

        if (!asset.active) {
            return;
        }

        asset.active = false;

        emit HederaAssetDeactivated(investmentId, asset.securityAddress);
    }

    /// @inheritdoc IHederaTokenization
    /// @notice Returns the Hedera asset associated with an investment.
    /// @dev If the investment has not been registered, the function returns
    ///      the default value of the `HederaAsset` struct.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    /// @return asset Registered Hedera asset information.
    function getAsset(uint256 investmentId) external view returns (HederaAsset memory asset) {
        return _assets[investmentId];
    }

    /// @inheritdoc IHederaTokenization
    /// @notice Determines whether a Hedera asset has been registered for an
    ///         investment.
    /// @dev Registration status is independent of the asset's `active` status.
    ///      A deactivated asset remains registered.
    ///
    /// @param investmentId Unique CoopChain investment identifier.
    /// @return registered True if an asset record exists for the investment.
    function isRegistered(uint256 investmentId) external view returns (bool registered) {
        return _assets[investmentId].createdAt != 0;
    }
}
