// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC1155 } from "solmate/tokens/ERC1155.sol";

/// @title MockCTF
/// @notice A simple ERC1155 token for testing (simulates Conditional Token Framework)
contract MockCTF is ERC1155 {
    /// @notice Mint tokens to an address
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    /// @notice Burn tokens from an address
    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }

    /// @notice Batch mint tokens to an address
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external {
        _batchMint(to, ids, amounts, "");
    }

    /// @notice Required by ERC1155
    function uri(uint256) public pure override returns (string memory) {
        return "";
    }
}
