// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import { IGrant } from './IGrant.sol';
import {IWorldID} from "world-id-contracts/interfaces/IWorldID.sol";
import {IWorldIDGroups} from "world-id-contracts/interfaces/IWorldIDGroups.sol";
import {ByteHasher} from "world-id-contracts/libraries/ByteHasher.sol";

/// @title World ID Airdrop example
/// @author Worldcoin
/// @notice Template contract for airdropping tokens to World ID users
contract WorldIDAirdrop {
    using ByteHasher for bytes;

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  ERRORS                                ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when restricted functions are called by not allowed addresses
    error Unauthorized();

    /// @notice Thrown when attempting to reuse a nullifier
    error InvalidNullifier();

    ///////////////////////////////////////////////////////////////////////////////
    ///                                  EVENTS                                ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when a grant is successfully claimed
    /// @param receiver The address that received the tokens
    event GrantClaimed(uint256 grantId, address receiver);

    /// @notice Emitted when the grant is changed
    /// @param grant The new grant instance
    event GrantUpdated(IGrant grant);

    ///////////////////////////////////////////////////////////////////////////////
    ///                              CONFIG STORAGE                            ///
    //////////////////////////////////////////////////////////////////////////////

    /// @dev The WorldID router instance that will be used for managing groups and verifying proofs
    IWorldIDGroups internal immutable worldIdRouter;

    /// @dev The World ID group whose participants can claim this airdrop
    uint256 internal immutable groupId;

    /// @notice The ERC20 token airdropped
    ERC20 public immutable token;

    /// @notice The address that holds the tokens that are being airdropped
    /// @dev Make sure the holder has approved spending for this contract!
    address public immutable holder;

    /// @notice The address that manages this airdrop, which is allowed to update the `airdropAmount`.
    address public immutable manager = msg.sender;

    /// @notice The grant instance used.
    IGrant private grant;

    /// @dev Whether a nullifier hash has been used already. Used to prevent double-signaling
    mapping(uint256 => bool) internal nullifierHashes;

    /// @dev Allowed addresses to call the `claim` function.
    mapping(address => bool) internal allowedCallers;

    ///////////////////////////////////////////////////////////////////////////////
    ///                               CONSTRUCTOR                              ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Deploys a WorldIDAirdrop instance
    /// @param _worldIdRouter The WorldID router that will manage groups and verify proofs
    /// @param _groupId The ID of the group World ID is using (`1`)
    /// @param _token The ERC20 token that will be airdropped to eligible participants
    /// @param _holder The address holding the tokens that will be airdropped
    /// @param _grant The grant that will be used to calculate the amount of tokens to airdrop
    constructor(
        IWorldIDGroups _worldIdRouter,
        uint256 _groupId,
        ERC20 _token,
        address _holder,
        IGrant _grant
    ) {
        worldIdRouter = _worldIdRouter;
        groupId = _groupId;
        token = _token;
        holder = _holder;
        grant = _grant;
    }

    ///////////////////////////////////////////////////////////////////////////////
    ///                               CLAIM LOGIC                               ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Claim the airdrop
    /// @param receiver The address that will receive the tokens (this is also the signal of the ZKP)
    /// @param root The root of the Merkle tree (signup-sequencer or world-id-contracts provides this)
    /// @param nullifierHash The nullifier for this proof, preventing double signaling
    /// @param proof The zero knowledge proof that demonstrates the claimer has a verified World ID
    /// @dev hashToField function docs are in lib/world-id-contracts/src/libraries/ByteHasher.sol
    function claim(uint256 grantId, address receiver, uint256 root, uint256 nullifierHash, uint256[8] calldata proof)
        public
    {
        if (!allowedCallers[msg.sender]) revert Unauthorized();
        if (nullifierHashes[nullifierHash]) revert InvalidNullifier();
        
        grant.checkValidity(grantId);

        worldIdRouter.verifyProof(
            groupId,
            root,
            abi.encodePacked(receiver).hashToField(),
            nullifierHash,
            grantId,
            proof
        );

        nullifierHashes[nullifierHash] = true;

        SafeTransferLib.safeTransferFrom(token, holder, receiver, grant.getAmount(grantId));

        emit GrantClaimed(grantId, receiver);
    }

    ///////////////////////////////////////////////////////////////////////////////
    ///                               CONFIG LOGIC                             ///
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Add a caller to the list of allowed callers
    /// @param _caller The address to add
    function addAllowedCaller(address _caller) public {
        if (msg.sender != manager) revert Unauthorized();
        allowedCallers[_caller] = true;
    }

    /// @notice Remove a caller to the list of allowed callers
    /// @param _caller The address to remove
    function removeAllowedCaller(address _caller) public {
        if (msg.sender != manager) revert Unauthorized();
        allowedCallers[_caller] = false;
    }

    /// @notice Update the grant. 
    /// @param _grant The new grant
    function setGrant(IGrant _grant) public {
        if (msg.sender != manager) revert Unauthorized();
        grant = _grant;
        emit GrantUpdated(_grant);
    }
}
