// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";

import { FeeModule } from "../../src/polymarket/FeeModule.sol";
import { NegRiskFeeModule } from "../../src/polymarket/NegRiskFeeModule.sol";
import { MockCollateral } from "../../src/polymarket/mocks/MockCollateral.sol";
import { MockCTF } from "../../src/polymarket/mocks/MockCTF.sol";
import { MockCTFExchange } from "../../src/polymarket/mocks/MockCTFExchange.sol";
import { Order, Side, SignatureType } from "../../src/polymarket/libraries/Structs.sol";

contract FeeModuleTest is Test {
    FeeModule public feeModule;
    MockCollateral public collateral;
    MockCTF public ctf;
    MockCTFExchange public exchange;

    address public admin = address(this);
    address public maker1 = address(0x1);
    address public maker2 = address(0x2);
    address public taker = address(0x3);

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant INITIAL_COLLATERAL = 1_000_000e6; // 1M USDC
    uint256 public constant INITIAL_CTF = 1_000_000e18; // 1M CTF tokens

    function setUp() public {
        // Deploy mock tokens
        collateral = new MockCollateral();
        ctf = new MockCTF();

        // Deploy mock exchange
        exchange = new MockCTFExchange(address(collateral), address(ctf));

        // Deploy FeeModule
        feeModule = new FeeModule(address(exchange));

        // Fund participants
        collateral.mint(maker1, INITIAL_COLLATERAL);
        collateral.mint(maker2, INITIAL_COLLATERAL);
        collateral.mint(taker, INITIAL_COLLATERAL);
        collateral.mint(address(feeModule), INITIAL_COLLATERAL); // For fee refunds

        ctf.mint(address(feeModule), TOKEN_ID, INITIAL_CTF); // For fee refunds in CTF
        ctf.mint(maker1, TOKEN_ID, INITIAL_CTF);
        ctf.mint(maker2, TOKEN_ID, INITIAL_CTF);
        ctf.mint(taker, TOKEN_ID, INITIAL_CTF);

        // Set up approvals
        vm.prank(maker1);
        collateral.approve(address(exchange), type(uint256).max);
        vm.prank(maker1);
        ctf.setApprovalForAll(address(exchange), true);

        vm.prank(maker2);
        collateral.approve(address(exchange), type(uint256).max);
        vm.prank(maker2);
        ctf.setApprovalForAll(address(exchange), true);

        vm.prank(taker);
        collateral.approve(address(exchange), type(uint256).max);
        vm.prank(taker);
        ctf.setApprovalForAll(address(exchange), true);

        // Note: FeeModule self-approval for CTF is handled in constructor
    }

    function testFeeModuleDeployment() public view {
        assertEq(address(feeModule.exchange()), address(exchange));
        assertEq(feeModule.collateral(), address(collateral));
        assertEq(feeModule.ctf(), address(ctf));
        assertTrue(feeModule.isAdmin(admin));
        // Verify self-approval for CTF is set in constructor (required for fee refunds)
        assertTrue(ctf.isApprovedForAll(address(feeModule), address(feeModule)));
    }

    function testMatchOrdersSingleMaker() public {
        // Create taker order (SELL CTF for collateral)
        Order memory takerOrder = Order({
            salt: 1,
            maker: taker,
            signer: taker,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 100e18,  // 100 CTF tokens
            takerAmount: 50e6,   // 50 USDC
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100, // 1%
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Create maker order (BUY CTF with collateral)
        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = Order({
            salt: 2,
            maker: maker1,
            signer: maker1,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e6,   // 50 USDC
            takerAmount: 100e18, // 100 CTF tokens
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100, // 1%
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = 50e6;

        uint256[] memory makerFeeAmounts = new uint256[](1);
        makerFeeAmounts[0] = 0;

        // Execute matchOrders
        feeModule.matchOrders(
            takerOrder,
            makerOrders,
            100e18,  // takerFillAmount
            50e6,    // takerReceiveAmount
            makerFillAmounts,
            0,       // takerFeeAmount
            makerFeeAmounts
        );
    }

    function testMatchOrdersMultipleMakers() public {
        // Create taker order
        Order memory takerOrder = Order({
            salt: 1,
            maker: taker,
            signer: taker,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 200e18,
            takerAmount: 100e6,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Create two maker orders
        Order[] memory makerOrders = new Order[](2);
        makerOrders[0] = Order({
            salt: 2,
            maker: maker1,
            signer: maker1,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e6,
            takerAmount: 100e18,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });
        makerOrders[1] = Order({
            salt: 3,
            maker: maker2,
            signer: maker2,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e6,
            takerAmount: 100e18,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        uint256[] memory makerFillAmounts = new uint256[](2);
        makerFillAmounts[0] = 50e6;
        makerFillAmounts[1] = 50e6;

        uint256[] memory makerFeeAmounts = new uint256[](2);
        makerFeeAmounts[0] = 0;
        makerFeeAmounts[1] = 0;

        feeModule.matchOrders(
            takerOrder,
            makerOrders,
            200e18,
            100e6,
            makerFillAmounts,
            0,
            makerFeeAmounts
        );
    }

    // NOTE: onlyAdmin modifier removed from matchOrders for load testing purposes
    // In production Polymarket, matchOrders requires admin privileges

    function testAddAndRemoveAdmin() public {
        address newAdmin = address(0x4);

        // Add admin
        feeModule.addAdmin(newAdmin);
        assertTrue(feeModule.isAdmin(newAdmin));

        // Remove admin
        feeModule.removeAdmin(newAdmin);
        assertFalse(feeModule.isAdmin(newAdmin));
    }

    function testWithdrawFees() public {
        uint256 feeAmount = 1000e6;

        // Check initial balance
        uint256 initialBalance = collateral.balanceOf(admin);

        // Withdraw fees (collateral, id = 0)
        feeModule.withdrawFees(admin, 0, feeAmount);

        // Check balance increased
        assertEq(collateral.balanceOf(admin), initialBalance + feeAmount);
    }

    // Helper functions
    function _createDefaultTakerOrder() internal view returns (Order memory) {
        return Order({
            salt: 1,
            maker: taker,
            signer: taker,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 100e18,
            takerAmount: 50e6,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });
    }

    function _createDefaultMakerOrder() internal view returns (Order memory) {
        return Order({
            salt: 2,
            maker: maker1,
            signer: maker1,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e6,
            takerAmount: 100e18,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });
    }
}

contract NegRiskFeeModuleTest is Test {
    NegRiskFeeModule public negRiskFeeModule;
    MockCollateral public collateral;
    MockCTF public ctf;
    MockCTFExchange public exchange;

    address public admin = address(this);
    address public negRiskAdapter = address(0x100);

    function setUp() public {
        // Deploy mock tokens
        collateral = new MockCollateral();
        ctf = new MockCTF();

        // Deploy mock exchange
        exchange = new MockCTFExchange(address(collateral), address(ctf));

        // Deploy NegRiskFeeModule
        negRiskFeeModule = new NegRiskFeeModule(
            address(exchange),
            negRiskAdapter,
            address(ctf)
        );
    }

    function testNegRiskFeeModuleDeployment() public view {
        assertEq(address(negRiskFeeModule.exchange()), address(exchange));
        assertEq(negRiskFeeModule.collateral(), address(collateral));
        assertEq(negRiskFeeModule.ctf(), address(ctf));
        assertTrue(negRiskFeeModule.isAdmin(admin));
    }

    function testCtfApprovals() public view {
        // Check that approvals were set in constructor
        assertTrue(ctf.isApprovedForAll(address(negRiskFeeModule), negRiskAdapter));
        assertTrue(ctf.isApprovedForAll(address(negRiskFeeModule), address(negRiskFeeModule)));
    }
}

contract FeeModuleFuzzTest is Test {
    FeeModule public feeModule;
    MockCollateral public collateral;
    MockCTF public ctf;
    MockCTFExchange public exchange;

    address public admin = address(this);
    address public maker1 = address(0x1);
    address public taker = address(0x3);

    uint256 public constant TOKEN_ID = 1;

    function setUp() public {
        collateral = new MockCollateral();
        ctf = new MockCTF();
        exchange = new MockCTFExchange(address(collateral), address(ctf));
        feeModule = new FeeModule(address(exchange));

        // Generous funding for fuzz tests
        collateral.mint(maker1, type(uint128).max);
        collateral.mint(taker, type(uint128).max);
        collateral.mint(address(feeModule), type(uint128).max);

        ctf.mint(maker1, TOKEN_ID, type(uint128).max);
        ctf.mint(taker, TOKEN_ID, type(uint128).max);
        ctf.mint(address(feeModule), TOKEN_ID, type(uint128).max); // For fee refunds

        vm.prank(maker1);
        collateral.approve(address(exchange), type(uint256).max);
        vm.prank(maker1);
        ctf.setApprovalForAll(address(exchange), true);

        vm.prank(taker);
        collateral.approve(address(exchange), type(uint256).max);
        vm.prank(taker);
        ctf.setApprovalForAll(address(exchange), true);

        // Note: FeeModule self-approval for CTF is now handled in constructor
    }

    function testFuzzMatchOrders(
        uint256 salt,
        uint256 makerAmount,
        uint256 takerAmount,
        uint256 feeRateBps
    ) public {
        // Bound inputs to reasonable ranges
        makerAmount = bound(makerAmount, 1e6, 1e24);
        takerAmount = bound(takerAmount, 1e6, 1e24);
        feeRateBps = bound(feeRateBps, 0, 1000); // Max 10%
        salt = bound(salt, 1, type(uint128).max);

        Order memory takerOrder = Order({
            salt: salt,
            maker: taker,
            signer: taker,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: makerAmount,
            takerAmount: takerAmount,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: feeRateBps,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = Order({
            salt: salt + 1,
            maker: maker1,
            signer: maker1,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: takerAmount,
            takerAmount: makerAmount,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: feeRateBps,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = takerAmount;

        uint256[] memory makerFeeAmounts = new uint256[](1);
        makerFeeAmounts[0] = 0;

        // This should not revert with properly bounded inputs
        feeModule.matchOrders(
            takerOrder,
            makerOrders,
            makerAmount,
            takerAmount,
            makerFillAmounts,
            0,
            makerFeeAmounts
        );
    }

    function testFuzzMultipleMakerOrders(
        uint256 salt,
        uint8 numMakers
    ) public {
        numMakers = uint8(bound(numMakers, 1, 5));
        salt = bound(salt, 1, type(uint64).max);

        uint256 baseAmount = 1e18;

        Order memory takerOrder = Order({
            salt: salt,
            maker: taker,
            signer: taker,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: baseAmount * numMakers,
            takerAmount: baseAmount * numMakers / 2,
            expiration: block.timestamp + 1 days,
            nonce: 0,
            feeRateBps: 100,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        Order[] memory makerOrders = new Order[](numMakers);
        uint256[] memory makerFillAmounts = new uint256[](numMakers);
        uint256[] memory makerFeeAmounts = new uint256[](numMakers);

        for (uint8 i = 0; i < numMakers; i++) {
            makerOrders[i] = Order({
                salt: salt + i + 1,
                maker: maker1,
                signer: maker1,
                taker: address(0),
                tokenId: TOKEN_ID,
                makerAmount: baseAmount / 2,
                takerAmount: baseAmount,
                expiration: block.timestamp + 1 days,
                nonce: i,
                feeRateBps: 100,
                side: Side.BUY,
                signatureType: SignatureType.EOA,
                signature: ""
            });
            makerFillAmounts[i] = baseAmount / 2;
            makerFeeAmounts[i] = 0;
        }

        feeModule.matchOrders(
            takerOrder,
            makerOrders,
            baseAmount * numMakers,
            baseAmount * numMakers / 2,
            makerFillAmounts,
            0,
            makerFeeAmounts
        );
    }
}

/// @title ContenderCompatibleTest
/// @notice Tests that simulate the exact setup used in contender's polymarket.toml
/// @dev These tests verify that no vm.prank/vm.startPrank is needed for FeeModule operations
///      after the constructor-based self-approval fix
contract ContenderCompatibleTest is Test {
    FeeModule public feeModule;
    NegRiskFeeModule public negRiskFeeModule;
    MockCollateral public collateral;
    MockCTF public ctf;
    MockCTFExchange public exchange;

    address public admin = address(this);
    address public spammer = address(0x999); // Simulates contender spammer

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant LARGE_AMOUNT = 1000000000000000000000000000; // 1e27

    function setUp() public {
        // Deploy contracts exactly as contender does
        collateral = new MockCollateral();
        ctf = new MockCTF();
        exchange = new MockCTFExchange(address(collateral), address(ctf));
        feeModule = new FeeModule(address(exchange));
        negRiskFeeModule = new NegRiskFeeModule(
            address(exchange),
            address(feeModule), // Using feeModule as dummy negRiskAdapter
            address(ctf)
        );

        // Mint tokens to spammer (contender setup step)
        collateral.mint(spammer, LARGE_AMOUNT);
        ctf.mint(spammer, TOKEN_ID, LARGE_AMOUNT);

        // Mint tokens to FeeModule for fee refunds (contender setup step)
        collateral.mint(address(feeModule), LARGE_AMOUNT);
        ctf.mint(address(feeModule), TOKEN_ID, LARGE_AMOUNT);

        // Mint tokens to NegRiskFeeModule for fee refunds (contender setup step)
        collateral.mint(address(negRiskFeeModule), LARGE_AMOUNT);
        ctf.mint(address(negRiskFeeModule), TOKEN_ID, LARGE_AMOUNT);

        // Spammer approves exchange (contender setup step)
        vm.prank(spammer);
        collateral.approve(address(exchange), type(uint256).max);
        vm.prank(spammer);
        ctf.setApprovalForAll(address(exchange), true);

        // NOTE: No FeeModule self-approval needed here!
        // It's now done automatically in the FeeModule constructor
    }

    /// @notice Verify FeeModule self-approval is set correctly after deployment
    function testFeeModuleSelfApprovalSetInConstructor() public view {
        assertTrue(ctf.isApprovedForAll(address(feeModule), address(feeModule)));
    }

    /// @notice Verify NegRiskFeeModule self-approval is set correctly after deployment
    function testNegRiskFeeModuleSelfApprovalSetInConstructor() public view {
        assertTrue(ctf.isApprovedForAll(address(negRiskFeeModule), address(negRiskFeeModule)));
    }

    /// @notice Test self-trading pattern used in contender benchmark
    /// @dev This is the exact pattern from polymarket.toml spam transactions
    function testSelfTradingMatchOrders() public {
        // Self-trade: same address (spammer) is both maker and taker
        // Taker order: SELL 100e18 CTF for 50e18 collateral
        Order memory takerOrder = Order({
            salt: 0,
            maker: spammer,
            signer: spammer,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 100e18,
            takerAmount: 50e18,
            expiration: 99999999999,
            nonce: 0,
            feeRateBps: 100, // 1% fee
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        // Maker order: BUY 100e18 CTF with 50e18 collateral
        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = Order({
            salt: 1,
            maker: spammer,
            signer: spammer,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e18,
            takerAmount: 100e18,
            expiration: 99999999999,
            nonce: 0,
            feeRateBps: 100, // 1% fee
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = 50e18;

        uint256[] memory makerFeeAmounts = new uint256[](1);
        makerFeeAmounts[0] = 0;

        // Execute matchOrders - this should succeed without any additional approvals
        feeModule.matchOrders(
            takerOrder,
            makerOrders,
            100e18,  // takerFillAmount
            50e18,   // takerReceiveAmount
            makerFillAmounts,
            0,       // takerFeeAmount
            makerFeeAmounts
        );
    }

    /// @notice Test NegRiskFeeModule self-trading pattern
    function testNegRiskSelfTradingMatchOrders() public {
        Order memory takerOrder = Order({
            salt: 100,
            maker: spammer,
            signer: spammer,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 100e18,
            takerAmount: 50e18,
            expiration: 99999999999,
            nonce: 0,
            feeRateBps: 100,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = Order({
            salt: 101,
            maker: spammer,
            signer: spammer,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e18,
            takerAmount: 100e18,
            expiration: 99999999999,
            nonce: 0,
            feeRateBps: 100,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = 50e18;

        uint256[] memory makerFeeAmounts = new uint256[](1);
        makerFeeAmounts[0] = 0;

        // Execute matchOrders on NegRiskFeeModule
        negRiskFeeModule.matchOrders(
            takerOrder,
            makerOrders,
            100e18,
            50e18,
            makerFillAmounts,
            0,
            makerFeeAmounts
        );
    }

    /// @notice Test multiple consecutive self-trades with unique salts (fuzz simulation)
    function testMultipleSelfTradesWithUniqueSalts() public {
        for (uint256 i = 0; i < 5; i++) {
            Order memory takerOrder = Order({
                salt: i * 2,
                maker: spammer,
                signer: spammer,
                taker: address(0),
                tokenId: TOKEN_ID,
                makerAmount: 100e18,
                takerAmount: 50e18,
                expiration: 99999999999,
                nonce: 0,
                feeRateBps: 100,
                side: Side.SELL,
                signatureType: SignatureType.EOA,
                signature: ""
            });

            Order[] memory makerOrders = new Order[](1);
            makerOrders[0] = Order({
                salt: i * 2 + 1,
                maker: spammer,
                signer: spammer,
                taker: address(0),
                tokenId: TOKEN_ID,
                makerAmount: 50e18,
                takerAmount: 100e18,
                expiration: 99999999999,
                nonce: 0,
                feeRateBps: 100,
                side: Side.BUY,
                signatureType: SignatureType.EOA,
                signature: ""
            });

            uint256[] memory makerFillAmounts = new uint256[](1);
            makerFillAmounts[0] = 50e18;

            uint256[] memory makerFeeAmounts = new uint256[](1);
            makerFeeAmounts[0] = 0;

            feeModule.matchOrders(
                takerOrder,
                makerOrders,
                100e18,
                50e18,
                makerFillAmounts,
                0,
                makerFeeAmounts
            );
        }
    }

    /// @notice Test that fee refunds in CTF work correctly (requires self-approval)
    /// @dev This specifically tests the code path that was broken before the fix
    function testFeeRefundInCTF() public {
        // Create order where refund would be in CTF (BUY side with fee)
        Order memory takerOrder = Order({
            salt: 1000,
            maker: spammer,
            signer: spammer,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 50e18,   // Offering collateral
            takerAmount: 100e18,  // Wanting CTF
            expiration: 99999999999,
            nonce: 0,
            feeRateBps: 100,
            side: Side.BUY,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        Order[] memory makerOrders = new Order[](1);
        makerOrders[0] = Order({
            salt: 1001,
            maker: spammer,
            signer: spammer,
            taker: address(0),
            tokenId: TOKEN_ID,
            makerAmount: 100e18,  // Offering CTF
            takerAmount: 50e18,   // Wanting collateral
            expiration: 99999999999,
            nonce: 0,
            feeRateBps: 100,
            side: Side.SELL,
            signatureType: SignatureType.EOA,
            signature: ""
        });

        uint256[] memory makerFillAmounts = new uint256[](1);
        makerFillAmounts[0] = 100e18;

        uint256[] memory makerFeeAmounts = new uint256[](1);
        makerFeeAmounts[0] = 0;

        // This should work because FeeModule now self-approves in constructor
        feeModule.matchOrders(
            takerOrder,
            makerOrders,
            50e18,   // takerFillAmount
            100e18,  // takerReceiveAmount (CTF)
            makerFillAmounts,
            0,
            makerFeeAmounts
        );
    }
}
