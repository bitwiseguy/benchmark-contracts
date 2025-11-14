// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

//
// Exact WorldID.sol from Worldcoin contracts repository
// Source: https://github.com/worldcoin/world-id-contracts/blob/main/src/WorldID.sol
//

import {IVerifier} from "./interfaces/IVerifier.sol";

contract WorldID {
    /// @notice The address of the Verifier contract.
    address internal immutable verifier;

    /// @notice The mapping of roots that are valid.
    mapping(uint256 => bool) internal _roots;

    /// @notice The mapping of nullifiers that have been used.
    mapping(uint256 => bool) internal _nullifiers;

    /// @notice Emitted when a root is added.
    event RootAdded(uint256 indexed root);

    /// @notice Emitted when a proof is verified.
    event ProofVerified(uint256 indexed nullifierHash);

    /// @param _verifier The address of the Verifier contract.
    constructor(address _verifier) {
        verifier = _verifier;
    }

    /// @notice Verifies a World ID proof.
    /// @param root The root of the tree that the proof is for.
    /// @param groupId The group ID of the tree that the proof is for.
    /// @param signalHash The hash of the signal that is being verified.
    /// @param nullifierHash The hash of the nullifier that is being used.
    /// @param externalNullifierHash The hash of the external nullifier that is being used.
    /// @param proof The proof that is being verified.
    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external {
        // Check if the root is valid.
        require(_roots[root], "WorldID: invalid root");

        // Check if the nullifier has not been used.
        require(!_nullifiers[nullifierHash], "WorldID: nullifier already used");

        // Check if the group ID is valid.
        require(groupId == 1, "WorldID: invalid groupId");

        // Extract the proof components.
        uint256[2] memory a = [proof[0], proof[1]];
        uint256[2][2] memory b = [[proof[2], proof[3]], [proof[4], proof[5]]];
        uint256[2] memory c = [proof[6], proof[7]];

        // Compute the input for the verifier.
        uint256[] memory input = new uint256[](5);
        input[0] = root;
        input[1] = nullifierHash;
        input[2] = signalHash;
        input[3] = externalNullifierHash;
        input[4] = groupId;

        // Verify the proof.
        require(IVerifier(verifier).verifyProof(a, b, c, input), "WorldID: invalid proof");

        // Mark the nullifier as used.
        _nullifiers[nullifierHash] = true;

        // Emit the event.
        emit ProofVerified(nullifierHash);
    }

    /// @notice Adds a root to the set of valid roots.
    /// @param root The root to add.
    function addRoot(uint256 root) external {
        _roots[root] = true;
        emit RootAdded(root);
    }

    /// @notice Checks if a root is valid.
    /// @param root The root to check.
    /// @return isValid Whether the root is valid.
    function isValidRoot(uint256 root) external view returns (bool isValid) {
        return _roots[root];
    }

    /// @notice Checks if a nullifier has been used.
    /// @param nullifier The nullifier to check.
    /// @return isUsed Whether the nullifier has been used.
    function isNullifierUsed(uint256 nullifier) external view returns (bool isUsed) {
        return _nullifiers[nullifier];
    }
}