// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { FeeModule, IExchange } from "./FeeModule.sol";
import { IConditionalTokens } from "./interfaces/IConditionalTokens.sol";

/// @title NegRiskFeeModule
/// @notice A slightly modified version of FeeModule
/// @notice with added approvals for the NegRiskAdapter
contract NegRiskFeeModule is FeeModule {
    constructor(address _negRiskCtfExchange, address _negRiskAdapter, address _ctf) FeeModule(_negRiskCtfExchange) {
        // Approve NegRiskAdapter for CTF transfers
        IConditionalTokens(_ctf).setApprovalForAll(_negRiskAdapter, true);
        // Note: Self-approval is already done in FeeModule constructor
    }
}
