// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "solmate/tokens/ERC20.sol";

/// @title MockCollateral
/// @notice A simple ERC20 token for testing (simulates USDC.e)
/// @dev Includes dummy storage reads to simulate USDC.e blacklist/pause gas costs
contract MockCollateral is ERC20 {
    /// @notice Dummy blacklist mapping to simulate USDC.e gas costs
    mapping(address => bool) public blacklisted;

    /// @notice Dummy pause flag to simulate USDC.e gas costs
    bool public paused;

    constructor() ERC20("Mock USDC", "USDC", 6) {}

    /// @notice Mint tokens to an address
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burn tokens from an address
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @notice Override transfer to simulate USDC.e blacklist/pause checks
    function transfer(address to, uint256 amount) public override returns (bool) {
        // Simulate USDC.e compliance checks
        blacklisted[msg.sender];
        blacklisted[to];
        paused;

        return super.transfer(to, amount);
    }

    /// @notice Override transferFrom to simulate USDC.e blacklist/pause checks
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // Simulate USDC.e compliance checks
        blacklisted[from];
        blacklisted[to];
        paused;

        return super.transferFrom(from, to, amount);
    }
}
