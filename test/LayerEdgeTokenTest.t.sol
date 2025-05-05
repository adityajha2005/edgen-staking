//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LayerEdgeToken} from "@src/LayerEdgeToken.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract LayerEdgeTokenTest is Test {
    ERC20 public token;

    function setUp() public {
        uint256 totalSupply = 1000000000 * 10 ** 18;
        token = ERC20(new LayerEdgeToken("LayerEdge", "EDGEN", totalSupply, msg.sender));
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1000000000 * 10 ** 18);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "LayerEdge");
        assertEq(token.symbol(), "EDGEN");
    }
}
