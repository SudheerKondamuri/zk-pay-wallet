// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Defines the standard interface for a SNARK/STARK verifier on-chain.
interface IZKVerifier {
    // Returns true if the proof is valid against the public inputs.
    function verifyProof(
        bytes calldata proof,
        uint256[] calldata publicInputs
    ) external view returns (bool);
}
