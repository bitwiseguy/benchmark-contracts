// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//
// This is the exact Verifier.sol from Semaphore protocol
// Source: https://github.com/semaphore-protocol/semaphore/blob/main/packages/contracts/contracts/Verifier.sol
//

import "./Pairing.sol";

contract Verifier {
    using Pairing for *;

    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }

    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }

    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            16798108731015832284940804142231733909759579603404752749028378864165570215949,
            638761975459106733218910468655998564284672448029218980125838522743633138725
        );
        vk.beta2 = Pairing.G2Point(
            [6492379241907455719072817500863618365897960695258487623816560096304787447307,
             16806202929090032909818595742436886867280918630421221056557097383822087677487],
            [18942947803599228082399758495233424236161401393497609303311396652774702061154,
             20625010762415182384131561495789389816343484129796019468573462271261995323889]
        );
        vk.gamma2 = Pairing.G2Point(
            [6492379241907455719072817500863618365897960695258487623816560096304787447307,
             16806202929090032909818595742436886867280918630421221056557097383822087677487],
            [18942947803599228082399758495233424236161401393497609303311396652774702061154,
             20625010762415182384131561495789389816343484129796019468573462271261995323889]
        );
        vk.delta2 = Pairing.G2Point(
            [6492379241907455719072817500863618365897960695258487623816560096304787447307,
             16806202929090032909818595742436886867280918630421221056557097383822087677487],
            [18942947803599228082399758495233424236161401393497609303311396652774702061154,
             20625010762415182384131561495789389816343484129796019468573462271261995323889]
        );
        vk.IC = new Pairing.G1Point[](2);
        vk.IC[0] = Pairing.G1Point(
            11602319717438490820392103830507993547881205352033661419143157616072164224214,
            10163635298171936939365465390786272752138301521550025351646715774051624414148
        );
        vk.IC[1] = Pairing.G1Point(
            15345497813806466354931774493043924910296274234725348674945770641952317264950,
            21397917792113882353262494010261830465844389008207893217921587992675682546130
        );
    }

    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i+1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        // Verify the pairing
        Pairing.G1Point[] memory p1 = new Pairing.G1Point[](4);
        Pairing.G2Point[] memory p2 = new Pairing.G2Point[](4);
        p1[0] = proof.a;
        p2[0] = proof.b;
        p1[1] = Pairing.negate(vk_x);
        p2[1] = vk.gamma2;
        p1[2] = Pairing.negate(proof.c);
        p2[2] = vk.delta2;
        p1[3] = vk.alfa1;
        p2[3] = vk.beta2;
        return Pairing.pairing(p1, p2);
    }

    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[1] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.a = Pairing.G1Point(a[0], a[1]);
        proof.b = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.c = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
