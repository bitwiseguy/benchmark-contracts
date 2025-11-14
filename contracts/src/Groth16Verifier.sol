// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title Groth16Verifier
 * @notice Simulates World ID proof-of-humanity verification for stress testing
 * @dev Based on Semaphore protocol Groth16 verifier structure
 * 
 * BENCHMARKING MODE: This contract executes all expensive operations (ecPairing, ecMul, ecAdd)
 * but accepts all proofs to simulate realistic traffic where users only submit valid proofs.
 * This represents production usage better than having 99% of transactions revert.
 */
contract Groth16Verifier {
    // BN254 curve scalar field modulus
    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    
    // Track used nullifiers to prevent double-signaling (realistic state growth)
    mapping(uint256 => bool) public nullifierHashes;
    
    // Simulated Merkle roots (in real World ID, this comes from IdentityManager)
    mapping(uint256 => bool) public validRoots;
    
    // Events matching real World ID interface
    event ProofVerified(uint256 indexed nullifierHash, uint256 root);
    event RootAdded(uint256 indexed root);
    
    // Groth16 Verification Key Constants
    // These are placeholder values representing the World ID Semaphore circuit VK
    // In production, these come from circuit compilation (setup ceremony)
    
    // Alpha point (G1)
    uint256 constant ALPHA_X = 20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant ALPHA_Y = 9383485363053290200918347156157836566562967994039712273449902621266178545958;
    
    // Beta point (G2) - NEGATED for pairing check
    uint256 constant BETA_NEG_X_0 = 6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant BETA_NEG_X_1 = 4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant BETA_NEG_Y_0 = 11383000245469012944693504663162918391286475477077232690815866754273895001727;
    uint256 constant BETA_NEG_Y_1 = 41207766310529818958173054109690360505148424997958324311878202295167071904;
    
    // Gamma point (G2) - NEGATED for pairing check
    uint256 constant GAMMA_NEG_X_0 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant GAMMA_NEG_X_1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant GAMMA_NEG_Y_0 = 13392588948715843804641432497768002650278120570034223513918757245338268106653;
    uint256 constant GAMMA_NEG_Y_1 = 17805874995975841540914202342111839520379459829704422454583296818431106115052;
    
    // Delta point (G2) - NEGATED for pairing check
    uint256 constant DELTA_NEG_X_0 = 15028154694713144242204861571552635520290993855826554325002991692907421516918;
    uint256 constant DELTA_NEG_X_1 = 10202326166286888893675634318107715186834588694714750762952081034135561546271;
    uint256 constant DELTA_NEG_Y_0 = 9121952986466441409625823112409402110610350380222160673756836983949377617226;
    uint256 constant DELTA_NEG_Y_1 = 3402203030459169245973828223647408421795734658790470725360311404592929738724;
    
    // IC (public input commitment) points (G1)
    // CONSTANT is IC[0], PUB_0 through PUB_3 are IC[1] through IC[4]
    uint256 constant CONSTANT_X = 1452272927738590248356371174422184656932731110936062990115610832462181634644;
    uint256 constant CONSTANT_Y = 3608050114233210789542189629343107890943266759827387991788718454179833288695;
    
    uint256 constant PUB_0_X = 14798240452388909327945424685903532333765637883272751382037716636327236955001;
    uint256 constant PUB_0_Y = 10773894897711848209682368488916121016695006898681985691467605219098835500201;
    
    uint256 constant PUB_1_X = 17204267933132009093604099819536245144503489322639121825381131096467570698650;
    uint256 constant PUB_1_Y = 7704298975420304156332734115679983371345754866278811368869074990486717531131;

    uint256 constant PUB_2_X = 8060465662017324080560848316478407038163145149983639907596180500095598669247;
    uint256 constant PUB_2_Y = 20475082166427284188002500222093571716651248980245637602667562336751029856573;
    
    uint256 constant PUB_3_X = 7457566682692308112726332096733260585025339741083447785327706250123165087868;
    uint256 constant PUB_3_Y = 11904519443874922292602150685069370036383697877657723976244907400392778002614;
    
    constructor() {
        // Add a default root for testing (represents an initialized identity tree)
        validRoots[1] = true;
        emit RootAdded(1);
    }
    
    /**
     * @notice Verify a World ID proof
     * @dev This matches the real World ID verifyProof interface exactly
     * @param root The Merkle root to verify against (proves user is in the identity tree)
     * @param groupId The group identifier (1 for Orb-verified users)
     * @param signalHash Keccak256 hash of the signal (e.g., action identifier)
     * @param nullifierHash Unique hash to prevent double-signaling
     * @param externalNullifierHash The hash of the external nullifier
     * @param proof The Groth16 proof [a.x, a.y, b.x0, b.x1, b.y0, b.y1, c.x, c.y]
     * @return True if verification succeeds
     */
    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external returns (bool) {
        // Step 1: Validate the Merkle root (ensures user is in identity set)
        require(validRoots[root], "Groth16Verifier: invalid root");
        
        // Step 2: Check nullifier hasn't been used (prevents double-signaling)
        require(!nullifierHashes[nullifierHash], "Groth16Verifier: nullifier already used");
        
        // Step 3: Validate group ID (World ID uses 1 for Orb-verified)
        require(groupId == 1, "Groth16Verifier: invalid group ID");
        
        // Step 4: Compute the input array matching WorldID.sol exactly
        // WorldID.sol builds: [root, nullifierHash, signalHash, externalNullifierHash, groupId]
        uint256[] memory input = new uint256[](5);
        input[0] = root;
        input[1] = nullifierHash;
        input[2] = signalHash;
        input[3] = externalNullifierHash;
        input[4] = groupId;
        
        // Step 5: Compute the linear combination of public inputs
        // This performs: vk_x = IC[0] + input[0]*IC[1] + input[1]*IC[2] + input[2]*IC[3] + input[3]*IC[4] + input[4]*IC[5]
        // Uses ecMul (0x07) and ecAdd (0x06) precompiles
        uint256[2] memory vk_x = computePublicInputs(input);
        
        // Step 6: Perform the Groth16 pairing check
        // Pass proof directly from calldata instead of extracting to memory
        pairingCheck(proof, vk_x);
        
        // BENCHMARKING NOTE:
        // In production World ID, we would require(pairingResult, "Invalid proof")
        // For stress testing, we skip this check to simulate traffic where all
        // submitted proofs are valid (which is the real-world case).
        // The pairing check still executes fully, consuming ~150k gas.
        
        // Step 7: Mark nullifier as used (realistic state growth)
        // This is a cold SSTORE (~20k gas) on first use for this nullifier
        nullifierHashes[nullifierHash] = true;
        
        // Step 8: Emit verification event
        emit ProofVerified(nullifierHash, root);
        
        return true;
    }
    
   /**
     * @notice Compute the linear combination of public inputs with IC points
     * @dev Performs: vk_x = CONSTANT + input[0]*PUB_0 + input[1]*PUB_1 + input[2]*PUB_2 + input[3]*PUB_3 + input[4]*PUB_0
     * Matches SemaphoreVerifier's publicInputMSM logic but handles 5 inputs instead of 4
     * For the 5th input (groupId), we reuse PUB_0 since SemaphoreVerifier only has 4 PUB points
     */
    function computePublicInputs(
        uint256[] memory input
    ) internal view returns (uint256[2] memory) {
        // Start with zero point
        uint256 x = 0;
        uint256 y = 0;
        
        // Process each input: vk_x += input[i] * PUB[i]
        // SemaphoreVerifier has PUB_0 through PUB_3 (IC[1] through IC[4])
        // We have 5 inputs, so we'll use PUB_0 for input[4] (groupId)
        require(input.length == 5, "WorldIDVerifier: invalid input length");

                
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < SNARK_SCALAR_FIELD, "WorldIDVerifier: input >= SNARK_SCALAR_FIELD");
            
            uint256 pub_x;
            uint256 pub_y;
            
            if (i == 0) {
                (pub_x, pub_y) = (PUB_0_X, PUB_0_Y);
            } else if (i == 1) {
                (pub_x, pub_y) = (PUB_1_X, PUB_1_Y);
            } else if (i == 2) {
                (pub_x, pub_y) = (PUB_2_X, PUB_2_Y);
            } else if (i == 3) {
                (pub_x, pub_y) = (PUB_3_X, PUB_3_Y);
            } else { // i == 4 (groupId)
                (pub_x, pub_y) = (PUB_0_X, PUB_0_Y); // Reuse PUB_0 for 5th input
            }
            
            (uint256 mul_x, uint256 mul_y) = ecMul(pub_x, pub_y, input[i]);
            (x, y) = ecAdd(x, y, mul_x, mul_y);
        }
        
        // Add CONSTANT (IC[0]) last (matching SemaphoreVerifier: vk_x = CONSTANT + sum(input[i] * PUB[i]))
        (x, y) = ecAdd(x, y, CONSTANT_X, CONSTANT_Y);
        
        return [x, y];
    }
        
    
 function pairingCheck(
        uint256[8] calldata proof,
        uint256[2] memory vk_x
    ) internal view returns (bool) {
        // Validate all G1 points are on curve
        require(isValidG1Point(proof[0], proof[1]), "Invalid G1 point A");
        require(isValidG1Point(proof[6], proof[7]), "Invalid G1 point C");
        require(isValidG1Point(vk_x[0], vk_x[1]), "Invalid G1 point vk_x");
        require(isValidG1Point(ALPHA_X, ALPHA_Y), "Invalid G1 point ALPHA");
        
        // Validate G2 point B is in valid field range
        // Proof format: [a.x, a.y, b.x1, b.x0, b.y1, b.y0, c.x, c.y]
        require(isValidG2PointRange(proof[3], proof[2], proof[5], proof[4]), "Invalid G2 point B range");
        
        // Validate verification key G2 points are in valid range
        require(isValidG2PointRange(BETA_NEG_X_0, BETA_NEG_X_1, BETA_NEG_Y_0, BETA_NEG_Y_1), "Invalid G2 point BETA");
        require(isValidG2PointRange(GAMMA_NEG_X_0, GAMMA_NEG_X_1, GAMMA_NEG_Y_0, GAMMA_NEG_Y_1), "Invalid G2 point GAMMA");
        require(isValidG2PointRange(DELTA_NEG_X_0, DELTA_NEG_X_1, DELTA_NEG_Y_0, DELTA_NEG_Y_1), "Invalid G2 point DELTA");


        // Construct input for bn256Pairing precompile
        // Format: 6 * 32 bytes per G1/G2 pair
        uint256[24] memory input;
        
        // First pairing: e(A, B)
        // Proof format from Rust: [a.x, a.y, b.x1, b.x0, b.y1, b.y0, c.x, c.y]
        input[0] = proof[0];  // a.x
        input[1] = proof[1];  // a.y
        input[2] = proof[2];  // b.x1 (imaginary) - pairing precompile expects this order
        input[3] = proof[3];  // b.x0 (real)
        input[4] = proof[4];  // b.y1 (imaginary)
        input[5] = proof[5];  // b.y0 (real)
        
        // Second pairing: e(C, -delta)
        input[6] = proof[6];  // c.x
        input[7] = proof[7];  // c.y
        input[8] = DELTA_NEG_X_1;
        input[9] = DELTA_NEG_X_0;
        input[10] = DELTA_NEG_Y_1;
        input[11] = DELTA_NEG_Y_0;

        // Third pairing: e(alpha, -beta)
        input[12] = ALPHA_X;
        input[13] = ALPHA_Y;
        input[14] = BETA_NEG_X_1;
        input[15] = BETA_NEG_X_0;
        input[16] = BETA_NEG_Y_1;
        input[17] = BETA_NEG_Y_0;
        
        // Fourth pairing: e(vk_x, -gamma)
        input[18] = vk_x[0];
        input[19] = vk_x[1];
        input[20] = GAMMA_NEG_X_1;
        input[21] = GAMMA_NEG_X_0;
        input[22] = GAMMA_NEG_Y_1;
        input[23] = GAMMA_NEG_Y_0;
        
        uint256[1] memory out;
        bool success;
        
        assembly {
            success := staticcall(gas(), 0x08, input, 0x300, out, 0x20)
        }
        require(success, "WorldIDVerifier: pairing check failed 3");
        
        return true;
    }
    
    /**
     * @notice Elliptic curve scalar multiplication (BN254 G1)
     * @dev Uses ecMul precompile (0x07) - costs ~6k gas
     */
    function ecMul(uint256 x, uint256 y, uint256 scalar)
        internal
        view
        returns (uint256, uint256)
    {
        uint256[3] memory input = [x, y, scalar];
        uint256[2] memory result;
        
        bool success;
        assembly {
            success := staticcall(gas(), 0x07, input, 0x60, result, 0x40)
        }
        require(success, "WorldIDVerifier: ecMul failed");
        
        return (result[0], result[1]);
    }
    
    /**
     * @notice Elliptic curve point addition (BN254 G1)
     * @dev Uses ecAdd precompile (0x06) - costs ~500 gas
     */
    function ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
        internal
        view
        returns (uint256, uint256)
    {
        uint256[4] memory input = [x1, y1, x2, y2];
        uint256[2] memory result;
        
        bool success;
        assembly {
            success := staticcall(gas(), 0x06, input, 0x80, result, 0x40)
        }
        require(success, "WorldIDVerifier: ecAdd failed");
        
        return (result[0], result[1]);
    }
    
    // ============ Admin Functions for Testing ============
    
    /**
     * @notice Add a Merkle root to the valid roots set
     * @dev In production World ID, this is managed by IdentityManager
     */
    function addRoot(uint256 root) external {
        validRoots[root] = true;
        emit RootAdded(root);
    }
    
    /**
     * @notice Check if a nullifier has been used
     * @dev Useful for debugging and monitoring
     */
    function isNullifierUsed(uint256 nullifierHash) external view returns (bool) {
        return nullifierHashes[nullifierHash];
    }

    /**
     * @notice Validate that a G1 point is on the BN254 curve using ecMul precompile
     * @dev Uses ecMul with scalar 1 - if it succeeds, the point is valid
     */
    function isValidG1Point(uint256 x, uint256 y) public view returns (bool) {
        uint256 p = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
        
        // Check points are in field
        if (x >= p || y >= p) {
            return false;
        }
        
        // Point at infinity is (0, 0) - this is valid but special case
        if (x == 0 && y == 0) {
            return true;
        }
        
        // Use ecMul precompile with scalar 1 to verify point is on curve
        // If the point is invalid, ecMul will fail
        uint256[3] memory input = [x, y, 1];
        uint256[2] memory result;
        
        bool success;
        assembly {
            success := staticcall(gas(), 0x07, input, 0x60, result, 0x40)
        }
        
        // If ecMul succeeds, the point is valid (on curve and in correct subgroup)
        return success;
    }

        /**
     * @notice Validate G2 point coordinates are in valid field range
     * @dev Full G2 curve validation is complex, so we just check field bounds
     */
    function isValidG2PointRange(
        uint256 x0, uint256 x1,
        uint256 y0, uint256 y1
    ) public pure returns (bool) {
        uint256 p = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
        
        // Check all coordinates are in field
        return (x0 < p && x1 < p && y0 < p && y1 < p);
    }
}