// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LayerEdgeStaking} from "@src/stake/LayerEdgeStaking.sol";
import {DeployLayerEdgeStakingNative} from "@script/DeployLayerEdgeStaking.s.sol";
import {NetworkConfig, HelperConfig} from "@script/HelperConfig.s.sol";
import {WETH9} from "@src/WETH9.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";

contract NativeTokenFuzzTest is Test {
    LayerEdgeStaking public staking;
    WETH9 public weth;
    HelperConfig public helperConfig;
    DeployLayerEdgeStakingNative public deployer;

    address public admin;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant MIN_STAKE = 3000 ether;
    uint256 public constant MAX_STAKE = 100_000 ether;

    function setUp() public {
        deployer = new DeployLayerEdgeStakingNative();
        (staking, helperConfig) = deployer.run();

        NetworkConfig memory config = helperConfig.getActiveNetworkConfigNative();
        admin = config.owner;
        weth = WETH9(payable(config.stakingToken));

        vm.startPrank(admin);
        uint256 rewardAmount = 1_000_000 ether;
        vm.deal(admin, rewardAmount);
        IWETH(address(weth)).deposit{value: rewardAmount}();
        IWETH(address(weth)).approve(address(staking), rewardAmount);
        staking.depositRewards(rewardAmount);
        staking.setCompoundingStatus(true);
        vm.stopPrank();
    }

    function testFuzz_StakeNative(uint256 amount) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        vm.deal(alice, amount);
        vm.prank(alice);
        staking.stakeNative{value: amount}();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_UnstakeNative(uint256 stakeAmount, uint256 unstakeAmount) public {
        stakeAmount = bound(stakeAmount, MIN_STAKE, MAX_STAKE);
        unstakeAmount = bound(unstakeAmount, 1, stakeAmount);

        vm.deal(alice, stakeAmount);
        vm.startPrank(alice);
        staking.stakeNative{value: stakeAmount}();
        staking.unstake(unstakeAmount);
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, stakeAmount - unstakeAmount);
    }

    function testFuzz_ClaimInterest(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 30 days);

        vm.deal(alice, amount);
        vm.startPrank(alice);
        staking.stakeNative{value: amount}();
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        staking.claimInterestNative();
        uint256 balanceAfter = alice.balance;

        assertGe(balanceAfter, balanceBefore);
    }

    function testFuzz_CompleteUnstake(uint256 amount) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        vm.deal(alice, amount);
        vm.startPrank(alice);
        staking.stakeNative{value: amount}();
        staking.unstake(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days + 1);

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        staking.completeUnstakeNative(0);
        uint256 balanceAfter = alice.balance;

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function testFuzz_Compounding(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 30 days);

        vm.deal(alice, amount);
        vm.startPrank(alice);
        staking.stakeNative{value: amount}();
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        vm.startPrank(alice);
        staking.compoundInterest();
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertGe(stakedAmount, amount);
    }

    function testFuzz_MultipleUsers(uint8 userCount, uint256 amount) public {
        userCount = uint8(bound(userCount, 1, 5));
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            vm.deal(user, amount);
            vm.prank(user);
            staking.stakeNative{value: amount}();
        }

        (uint256 tier1Count, uint256 tier2Count, uint256 tier3Count) = staking.getTierCounts();
        assertEq(tier1Count + tier2Count + tier3Count, userCount);
    }

    function testFuzz_SmallAmounts(uint256 amount) public {
        amount = bound(amount, 1 ether, MIN_STAKE - 1);

        vm.deal(alice, amount);
        vm.prank(alice);
        staking.stakeNative{value: amount}();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_LargeAmounts(uint256 amount) public {
        amount = bound(amount, MAX_STAKE, MAX_STAKE * 2);

        vm.deal(alice, amount);
        vm.prank(alice);
        staking.stakeNative{value: amount}();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_ZeroAmount() public {
        vm.deal(alice, 0);
        vm.prank(alice);
        vm.expectRevert("Cannot stake zero amount");
        staking.stakeNative{value: 0}();
    }

    function testFuzz_GasUsage(uint8 operations) public {
        operations = uint8(bound(operations, 1, 5));
        uint256 amount = MIN_STAKE;

        vm.deal(alice, amount * operations);
        vm.startPrank(alice);
        
        for (uint8 i = 0; i < operations; i++) {
            staking.stakeNative{value: amount}();
        }
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount * operations);
    }
}