// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//
// Full Pairing.sol from Semaphore protocol
// Source: https://github.com/semaphore-protocol/semaphore/blob/main/packages/contracts/contracts/Pairing.sol
//

library Pairing {
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }

    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
    }

    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, PRIME_Q - (p.Y % PRIME_Q));
    }

    function plus(G1Point memory p1, G1Point memory p2) view internal returns (G1Point memory r) {
        uint256[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0x80, r, 0x40)
        }
        require(success, "pairing-add-failed");
    }

    function scalar_mul(G1Point memory p, uint256 s) view internal returns (G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x60, r, 0x40)
        }
        require(success, "pairing-mul-failed");
    }

    function pairing(G1Point[] memory p1, G2Point[] memory p2) view internal returns (uint256) {
        require(p1.length == p2.length, "pairing-lengths-failed");
        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);
        for (uint256 i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint256[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        }
        require(success, "pairing-opcode-failed");
        return out[0];
    }

    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) view internal returns (uint256) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) view internal returns (uint256) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }

    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) view internal returns (uint256) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }

    function pairingProd5(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2,
            G1Point memory e1, G2Point memory e2
    ) view internal returns (uint256) {
        G1Point[] memory p1 = new G1Point[](5);
        G2Point[] memory p2 = new G2Point[](5);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p1[4] = e1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        p2[4] = e2;
        return pairing(p1, p2);
    }

    function verify(G1Point memory a, G2Point memory b, G1Point memory c, G1Point memory d, uint256 exponent) view internal returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a;
        p2[0] = b;
        p1[1] = c;
        p2[1] = P2();
        p1[2] = d;
        p2[2] = P2();
        p1[3] = negate(scalar_mul(P1(), exponent));
        p2[3] = P2();
        return pairing(p1, p2) == 0;
    }

    function isOnCurveG1(G1Point memory p) internal pure returns (bool) {
        if (p.X == 0 && p.Y == 0) return true;
        uint256 x3 = mulmod(p.X, mulmod(p.X, p.X, PRIME_Q), PRIME_Q);
        uint256 y2 = mulmod(p.Y, p.Y, PRIME_Q);
        return (x3 + 3) % PRIME_Q == y2 % PRIME_Q;
    }

    function isOnCurveG2(G2Point memory p) internal pure returns (bool) {
        if (p.X[0] == 0 && p.X[1] == 0 && p.Y[0] == 0 && p.Y[1] == 0) return true;
        // Field extension Fq2 = Fq[u]/(u^2 + 1)
        uint256[2] memory x3 = montgomerySquare(p.X);
        x3 = montgomeryMul(x3, p.X);
        uint256[2] memory y2 = montgomerySquare(p.Y);
        uint256[2] memory three = [uint256(3), uint256(0)];
        x3 = montgomeryAdd(x3, three);
        return montgomeryEqual(x3, y2);
    }

    function montgomerySquare(uint256[2] memory x) internal pure returns (uint256[2] memory) {
        uint256 a = mulmod(x[0], x[0], PRIME_Q);
        uint256 b = mulmod(x[1], x[1], PRIME_Q);
        uint256 c = mulmod(x[0], x[1], PRIME_Q);
        return [addmod(a, mulmod(b, 21888242871839275222246405745257275088696311157297823662689037894645226208582, PRIME_Q), PRIME_Q), addmod(c, c, PRIME_Q)];
    }

    function montgomeryMul(uint256[2] memory x, uint256[2] memory y) internal pure returns (uint256[2] memory) {
        uint256 a = mulmod(x[0], y[0], PRIME_Q);
        uint256 b = mulmod(x[1], y[1], PRIME_Q);
        uint256 c = mulmod(x[0], y[1], PRIME_Q);
        uint256 d = mulmod(x[1], y[0], PRIME_Q);
        return [addmod(a, mulmod(b, 21888242871839275222246405745257275088696311157297823662689037894645226208582, PRIME_Q), PRIME_Q), addmod(c, d, PRIME_Q)];
    }

    function montgomeryAdd(uint256[2] memory x, uint256[2] memory y) internal pure returns (uint256[2] memory) {
        return [addmod(x[0], y[0], PRIME_Q), addmod(x[1], y[1], PRIME_Q)];
    }

    function montgomeryEqual(uint256[2] memory x, uint256[2] memory y) internal pure returns (bool) {
        return x[0] == y[0] && x[1] == y[1];
    }

    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        return plus(p1, p2);
    }
}