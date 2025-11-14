// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

//
// Exact IVerifier.sol interface from Worldcoin contracts repository
// Source: https://github.com/worldcoin/world-id-contracts/blob/main/src/interfaces/IVerifier.sol
//

interface IVerifier {
    /// @notice Verifies a Groth16 proof.
    /// @param a The A component of the proof.
    /// @param b The B component of the proof.
    /// @param c The C component of the proof.
    /// @param input The input to the proof.
    /// @return isValid Whether the proof is valid.
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory input
    ) external view returns (bool isValid);
}
