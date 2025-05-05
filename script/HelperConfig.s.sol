//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DeployLayerEdgeToken} from "@script/DeployLayerEdgeToken.s.sol";
import {LayerEdgeToken} from "@src/LayerEdgeToken.sol";

struct NetworkConfig {
    address stakingToken;
    address owner;
}

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 84532) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory baseSepoliaConfig = NetworkConfig({
            stakingToken: 0x0000000000000000000000000000000000000000,
            owner: 0x0000000000000000000000000000000000000000
        });
        return baseSepoliaConfig;
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        DeployLayerEdgeToken deployer = new DeployLayerEdgeToken();
        LayerEdgeToken layerEdgeToken = deployer.run();

        NetworkConfig memory anvilConfig =
            NetworkConfig({stakingToken: address(layerEdgeToken), owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266});
        return anvilConfig;
    }
}
