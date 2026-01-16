# Justfile for benchmark-contracts

# Default recipe
default:
    @just --list

# Update the polymarket scenario TOML with compiled contract bytecodes
# Usage: just update-polymarket-scenario /path/to/polymarket.toml
update-polymarket-scenario TOML_PATH:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "==> Compiling contracts..."
    (cd contracts && forge build)
    
    echo "==> Extracting bytecodes..."
    
    # Define contract mappings: name -> (json_path, display_name)
    declare -A contracts=(
        ["collateral"]="contracts/out/MockCollateral.sol/MockCollateral.json|MockCollateral"
        ["ctf"]="contracts/out/MockCTF.sol/MockCTF.json|MockCTF"
        ["exchange"]="contracts/out/MockCTFExchange.sol/MockCTFExchange.json|MockCTFExchange"
        ["feeModule"]="contracts/out/FeeModule.sol/FeeModule.json|FeeModule"
    )
    
    # Extract all bytecodes into associative array
    declare -A bytecodes
    for name in "${!contracts[@]}"; do
        IFS='|' read -r json_path display_name <<< "${contracts[$name]}"
        if [ ! -f "$json_path" ]; then
            echo "ERROR: $json_path not found" >&2
            exit 1
        fi
        bytecode=$(jq -r '.bytecode.object' "$json_path")
        bytecodes[$name]="$bytecode"
        echo "  $display_name: ${#bytecode} chars"
    done
    
    echo "==> Updating {{TOML_PATH}}..."
    
    # Single-pass awk to update all bytecodes at once
    awk -v collateral="${bytecodes[collateral]}" \
        -v ctf="${bytecodes[ctf]}" \
        -v exchange="${bytecodes[exchange]}" \
        -v feeModule="${bytecodes[feeModule]}" '
        BEGIN {
            bytecodes["collateral"] = collateral
            bytecodes["ctf"] = ctf
            bytecodes["exchange"] = exchange
            bytecodes["feeModule"] = feeModule
        }
        # Match: [[create]] block start
        /^\[\[create\]\]/ { in_block=1; current_name="" }
        # Match: other section headers like [[setup]] or [spam]
        /^\[/ && !/^\[\[create\]\]/ { in_block=0; current_name="" }
        # Match: name = "value" and extract the value (BSD awk compatible)
        in_block && /^name[ \t]*=[ \t]*"/ {
            if (match($0, /"([^"]+)"/)) {
                current_name = substr($0, RSTART+1, RLENGTH-2)
            }
        }
        # Match: bytecode = "..." and replace if we have a bytecode for current_name
        in_block && current_name && /^bytecode[ \t]*=[ \t]*"/ && bytecodes[current_name] != "" {
            print "bytecode = \"" bytecodes[current_name] "\""
            next
        }
        { print }
    ' "{{TOML_PATH}}" > "{{TOML_PATH}}.tmp" && mv "{{TOML_PATH}}.tmp" "{{TOML_PATH}}"
    
    echo "==> Done!"

# Build contracts only
build:
    cd contracts && forge build

# Run tests
test:
    cd contracts && forge test

# Clean build artifacts
clean:
    cd contracts && forge clean
