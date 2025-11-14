# benchmark-contracts

Contains solidity smart contracts specifically designed to benchmark EVM execution clients.

# Usage

```
forge build
jq -r '.bytecode.object' out/Groth16Verifier.sol/Groth16Verifier.json
```

Copy the resulting output into a contender scenario toml file in the `bytecode` field.
