// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC1155 } from "solmate/tokens/ERC1155.sol";
import { ERC1155TokenReceiver } from "solmate/tokens/ERC1155.sol";

import { IExchange } from "../interfaces/IExchange.sol";
import { Order, Side, OrderStatus } from "../libraries/Structs.sol";

/// @title MockCTFExchange
/// @notice A simplified mock of the CTFExchange for testing FeeModule
/// @dev Simulates the core matchOrders functionality with realistic gas usage
contract MockCTFExchange is IExchange, ERC1155TokenReceiver {
    /// @notice The collateral token (ERC20)
    address public immutable collateralToken;

    /// @notice The CTF token (ERC1155)
    address public immutable ctfToken;

    /// @notice Order status tracking (simulates real exchange storage)
    mapping(bytes32 => OrderStatus) public orderStatus;

    /// @notice Registered token conditions
    mapping(uint256 => bytes32) public tokenConditions;

    /// @notice Nonce tracking per address
    mapping(address => uint256) public nonces;

    /// @notice EIP712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @notice Order typehash for EIP712
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 salt,address maker,address signer,address taker,uint256 tokenId,uint256 makerAmount,uint256 takerAmount,uint256 expiration,uint256 nonce,uint256 feeRateBps,uint8 side,uint8 signatureType)"
    );

    constructor(address _collateral, address _ctf) {
        collateralToken = _collateral;
        ctfToken = _ctf;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("MockCTFExchange"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Get the collateral token address
    function getCollateral() external view override returns (address) {
        return collateralToken;
    }

    /// @notice Get the CTF token address
    function getCtf() external view override returns (address) {
        return ctfToken;
    }

    /// @notice Register a token with a condition ID
    function registerToken(uint256 tokenId, bytes32 conditionId) external {
        tokenConditions[tokenId] = conditionId;
    }

    /// @notice Match orders - simplified version that simulates gas usage
    /// @dev This simulates the core exchange logic:
    ///      1. Validates orders (storage reads)
    ///      2. Updates order status (storage writes)
    ///      3. Transfers tokens (ERC20/ERC1155 transfers)
    function matchOrders(
        Order memory takerOrder,
        Order[] memory makerOrders,
        uint256 takerFillAmount,
        uint256[] memory makerFillAmounts
    ) external override {
        require(makerOrders.length == makerFillAmounts.length, "Length mismatch");

        // Hash and update taker order status (storage operations)
        bytes32 takerHash = hashOrder(takerOrder);
        OrderStatus storage takerStatus = orderStatus[takerHash];

        // Simulate validation - read existing state
        if (!takerStatus.isFilledOrCancelled) {
            takerStatus.remaining = takerOrder.makerAmount;
        }
        require(takerStatus.remaining >= takerFillAmount, "Insufficient remaining");

        // Update taker order (storage write)
        takerStatus.remaining -= takerFillAmount;
        if (takerStatus.remaining == 0) {
            takerStatus.isFilledOrCancelled = true;
        }

        uint256 totalTakerReceive = 0;

        // Process each maker order
        for (uint256 i = 0; i < makerOrders.length; i++) {
            Order memory makerOrder = makerOrders[i];
            uint256 makerFillAmount = makerFillAmounts[i];

            // Hash and update maker order status
            bytes32 makerHash = hashOrder(makerOrder);
            OrderStatus storage makerStatus = orderStatus[makerHash];

            if (!makerStatus.isFilledOrCancelled) {
                makerStatus.remaining = makerOrder.makerAmount;
            }
            require(makerStatus.remaining >= makerFillAmount, "Maker insufficient");

            makerStatus.remaining -= makerFillAmount;
            if (makerStatus.remaining == 0) {
                makerStatus.isFilledOrCancelled = true;
            }

            // Calculate amounts
            uint256 makerReceiveAmount = (makerFillAmount * makerOrder.takerAmount) / makerOrder.makerAmount;
            totalTakerReceive += makerFillAmount;

            // Simulate token transfers based on order sides
            if (makerOrder.side == Side.BUY) {
                // Maker is buying CTF with collateral
                // Transfer collateral from maker to taker
                ERC20(collateralToken).transferFrom(makerOrder.maker, takerOrder.maker, makerFillAmount);
                // Transfer CTF from taker to maker
                ERC1155(ctfToken).safeTransferFrom(takerOrder.maker, makerOrder.maker, makerOrder.tokenId, makerReceiveAmount, "");
            } else {
                // Maker is selling CTF for collateral
                // Transfer CTF from maker to taker
                ERC1155(ctfToken).safeTransferFrom(makerOrder.maker, takerOrder.maker, makerOrder.tokenId, makerFillAmount, "");
                // Transfer collateral from taker to maker
                ERC20(collateralToken).transferFrom(takerOrder.maker, makerOrder.maker, makerReceiveAmount);
            }
        }
    }

    /// @notice Hash an order for EIP712 signature
    function hashOrder(Order memory order) public view override returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        ORDER_TYPEHASH,
                        order.salt,
                        order.maker,
                        order.signer,
                        order.taker,
                        order.tokenId,
                        order.makerAmount,
                        order.takerAmount,
                        order.expiration,
                        order.nonce,
                        order.feeRateBps,
                        order.side,
                        order.signatureType
                    )
                )
            )
        );
    }

    /// @notice ERC1155 receiver hook
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    /// @notice ERC1155 batch receiver hook
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
