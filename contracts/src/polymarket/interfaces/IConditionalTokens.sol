// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title IERC1155
/// @notice ERC1155 interface
interface IERC1155 {
    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value
    );
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

/// @title IConditionalTokensEE
/// @notice ConditionalTokens Events and Errors
interface IConditionalTokensEE {
    event ConditionPreparation(
        bytes32 indexed conditionId, address indexed oracle, bytes32 indexed questionId, uint256 outcomeSlotCount
    );
    event ConditionResolution(
        bytes32 indexed conditionId, address indexed oracle, bytes32 indexed questionId, uint256 outcomeSlotCount
    );
    event PositionSplit(
        address indexed stakeholder, address collateralToken, bytes32 indexed parentCollectionId, bytes32 indexed conditionId, uint256[] partition, uint256 amount
    );
    event PositionsMerge(
        address indexed stakeholder, address collateralToken, bytes32 indexed parentCollectionId, bytes32 indexed conditionId, uint256[] partition, uint256 amount
    );
    event PayoutRedemption(
        address indexed redeemer, address collateralToken, bytes32 indexed parentCollectionId, bytes32 indexed conditionId, uint256[] indexSets, uint256 payout
    );
}

/// @title IConditionalTokens
/// @notice ConditionalTokens interface
interface IConditionalTokens is IERC1155, IConditionalTokensEE {
    function prepareCondition(address oracle, bytes32 questionId, uint256 outcomeSlotCount) external;
    function reportPayouts(bytes32 questionId, uint256[] calldata payouts) external;
    function splitPosition(
        address collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external;
    function mergePositions(
        address collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata partition,
        uint256 amount
    ) external;
    function redeemPositions(
        address collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external;
    function getConditionId(address oracle, bytes32 questionId, uint256 outcomeSlotCount)
        external
        pure
        returns (bytes32);
    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        external
        view
        returns (bytes32);
    function getPositionId(address collateralToken, bytes32 collectionId) external pure returns (uint256);
}
