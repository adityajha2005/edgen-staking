//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DeployLayerEdgeToken} from "@script/DeployLayerEdgeToken.s.sol";
import {DeployWETH9} from "@script/DeployWETH9.s.sol";
import {WETH9} from "@src/WETH9.sol";
import {LayerEdgeToken} from "@test/mock/LayerEdgeToken.sol";

struct NetworkConfig {
    address stakingToken;
    address owner;
}

contract HelperConfig is Script {
    NetworkConfig private activeNetworkConfig;
    NetworkConfig private activeNetworkConfigNative;

    constructor() {
        if (block.chainid == 84532) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
            activeNetworkConfigNative = getAnvilConfigNative();
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getActiveNetworkConfigNative() public view returns (NetworkConfig memory) {
        return activeNetworkConfigNative;
    }

    function getBaseSepoliaConfig() private pure returns (NetworkConfig memory) {
        NetworkConfig memory baseSepoliaConfig = NetworkConfig({
            stakingToken: 0x0000000000000000000000000000000000000000,
            owner: 0x0000000000000000000000000000000000000000
        });
        return baseSepoliaConfig;
    }

    function getAnvilConfig() private returns (NetworkConfig memory) {
        DeployLayerEdgeToken deployer = new DeployLayerEdgeToken();
        LayerEdgeToken layerEdgeToken = deployer.run();

        NetworkConfig memory anvilConfig =
            NetworkConfig({stakingToken: address(layerEdgeToken), owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266});
        return anvilConfig;
    }

    function getAnvilConfigNative() private returns (NetworkConfig memory) {
        DeployWETH9 deployer = new DeployWETH9();
        WETH9 weth = deployer.run();

        NetworkConfig memory anvilConfigNative =
            NetworkConfig({stakingToken: address(weth), owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266});

        return anvilConfigNative;
    }
}
