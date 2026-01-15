// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IAuthEE
/// @notice Auth Events and Errors
interface IAuthEE {
    /// @notice Thrown when caller is not admin
    error NotAdmin();

    /// @notice Emitted when a new admin is added
    event NewAdmin(address indexed admin, address indexed newAdmin);

    /// @notice Emitted when an admin is removed
    event RemovedAdmin(address indexed admin, address indexed removedAdmin);
}

/// @title IAuth
/// @notice Auth interface
interface IAuth is IAuthEE {
    function isAdmin(address addr) external view returns (bool);

    function addAdmin(address admin) external;

    function removeAdmin(address admin) external;

    function renounceAdmin() external;
}
