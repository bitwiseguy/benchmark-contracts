// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "solmate/tokens/ERC20.sol";

/// @title MockCollateral
/// @notice A simple ERC20 token for testing (simulates USDC.e)
contract MockCollateral is ERC20 {
    constructor() ERC20("Mock USDC", "USDC", 6) {}

    /// @notice Mint tokens to an address
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burn tokens from an address
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
