// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/CleanvestSettlement.sol";

/// @notice Rust ureticisi (merkle/examples/cross_check.rs) ile Solidity
///         computeRoot'unun BIREBIR ayni koku urettigini kanitlar.
contract MerkleCrossCheckTest is Test {
    CleanvestSettlement public settlement;

    function setUp() public {
        settlement = new CleanvestSettlement();
    }

    function testRustSolidityRootIdentical() public {
        // Rust: Order::new(1, addr(1), 1), (2, addr(2), 2), (3, addr(3), 3)
        bytes32 l0 = settlement.leafHash(1, address(1), 1);
        bytes32 l1 = settlement.leafHash(2, address(2), 2);
        bytes32 l2 = settlement.leafHash(3, address(3), 3);
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = l0;
        leaves[1] = l1;
        leaves[2] = l2;

        bytes32 solidityRoot = settlement.computeRoot(leaves);
        // Rust cargo run --example cross_check ciktisi:
        bytes32 rustRoot = 0x21e195d1eed3d788d369d7a3e5ec2e8f56b8c9c6113b5a6baf48b848e5c73518;
        assertEq(solidityRoot, rustRoot, "Rust ve Solidity koku BIREBIR olmali");
    }
}
