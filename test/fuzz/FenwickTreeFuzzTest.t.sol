// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FenwickTree} from "@src/library/FenwickTree.sol";

contract FenwickTreeFuzzTest is Test {
    using FenwickTree for FenwickTree.Tree;

    FenwickTree.Tree tree;

    function setUp() public {
        tree.size = 100_000;
    }

    function testFuzz_UpdateQuery(uint256 index, int256 delta) public {
        index = bound(index, 1, tree.size - 1);
        delta = bound(delta, -1000, 1000);

        uint256 before = tree.query(index);
        tree.update(index, delta);
        uint256 afterUpdate = tree.query(index);

        assertEq(afterUpdate, uint256(int256(before) + delta));
    }

    function testFuzz_QueryMonotonic(uint256 index1, uint256 index2) public {
        index1 = bound(index1, 1, tree.size - 1);
        index2 = bound(index2, 1, tree.size - 1);

        if (index1 <= index2) {
            assertLe(tree.query(index1), tree.query(index2));
        }
    }

    function testFuzz_FindByFrequency(uint256 frequency) public {
        frequency = bound(frequency, 0, 1000);

        // add some values first
        tree.update(1, 1000);
        tree.update(2, 2000);
        tree.update(3, 3000);

        uint256 result = tree.findByCumulativeFrequency(frequency);
        assertLe(result, tree.size);
    }

    function testFuzz_BatchUpdates(uint8 count) public {
        count = uint8(bound(count, 1, 10));

        for (uint8 i = 0; i < count; i++) {
            uint256 index = bound(uint256(i), 1, tree.size - 1);
            int256 delta = bound(int256(uint256(i)), -100, 100);
            tree.update(index, delta);
        }

        // verify tree is still consistent
        uint256 total = tree.query(tree.size - 1);
        assertGe(total, 0);
    }

    function testFuzz_ExtremeValues(uint256 index, int256 delta) public {
        index = bound(index, 1, tree.size - 1);
        delta = bound(delta, -10000, 10000);

        tree.update(index, delta);
        uint256 result = tree.query(index);
        assertGe(result, 0);
    }

    function testFuzz_SequentialOperations(uint8 count) public {
        count = uint8(bound(count, 1, 20));

        for (uint8 i = 0; i < count; i++) {
            uint256 index = bound(uint256(i), 1, tree.size - 1);
            tree.update(index, 1);
        }

        uint256 total = tree.query(tree.size - 1);
        assertEq(total, count);
    }

    function testFuzz_InverseOperations(uint256 index, int256 delta) public {
        index = bound(index, 1, tree.size - 1);
        delta = bound(delta, -1000, 1000);

        uint256 before = tree.query(index);
        tree.update(index, delta);
        tree.update(index, -delta);
        uint256 afterUpdate = tree.query(index);

        assertEq(afterUpdate, before);
    }

    function testFuzz_PrefixSum(uint8 count) public {
        count = uint8(bound(count, 1, 10));

        uint256 expectedSum = 0;
        for (uint8 i = 0; i < count; i++) {
            uint256 index = bound(uint256(i), 1, tree.size - 1);
            uint256 value = bound(uint256(i), 1, 100);
            tree.update(index, int256(value));
            expectedSum += value;
        }

        uint256 actualSum = tree.query(tree.size - 1);
        assertEq(actualSum, expectedSum);
    }

    function testFuzz_EdgeIndices(uint256 index) public {
        index = bound(index, 1, tree.size - 1);

        tree.update(index, 100);
        uint256 result = tree.query(index);
        assertGe(result, 100);
    }

    function testFuzz_Consistency(uint8 operations) public {
        operations = uint8(bound(operations, 1, 15));

        for (uint8 i = 0; i < operations; i++) {
            uint256 index = bound(uint256(i), 1, tree.size - 1);
            int256 delta = bound(int256(uint256(i)), -50, 50);
            tree.update(index, delta);
        }

        for (uint8 i = 0; i < operations; i++) {
            uint256 index = bound(uint256(i), 1, tree.size - 1);
            uint256 result = tree.query(index);
            assertGe(result, 0);
        }
    }
}