// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LayerEdgeStaking} from "@src/stake/LayerEdgeStaking.sol";
import {LayerEdgeToken} from "@test/mock/LayerEdgeToken.sol";
import {DeployLayerEdgeStaking} from "@script/DeployLayerEdgeStaking.s.sol";
import {NetworkConfig, HelperConfig} from "@script/HelperConfig.s.sol";
import {WETH9} from "@src/WETH9.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";

contract LayerEdgeStakingFuzzTest is Test {
    LayerEdgeStaking public staking;
    LayerEdgeToken public token;
    WETH9 public weth;
    HelperConfig public helperConfig;
    DeployLayerEdgeStaking public deployer;

    address public admin;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant MIN_STAKE = 3000 * 1e18;
    uint256 public constant MAX_STAKE = 100_000 * 1e18;
    uint256 public constant PRECISION = 1e18;

    function setUp() public {
        deployer = new DeployLayerEdgeStaking();
        (staking, helperConfig) = deployer.run();

        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        token = LayerEdgeToken(config.stakingToken);
        admin = config.owner;

        vm.startPrank(admin);
        uint256 rewardAmount = 1_000_000 * 1e18;
        token.approve(address(staking), rewardAmount);
        staking.depositRewards(rewardAmount);
        staking.setCompoundingStatus(true);
        staking.setMinStakeAmount(MIN_STAKE);
        vm.stopPrank();

        deal(address(token), alice, MAX_STAKE);
        deal(address(token), bob, MAX_STAKE);
        deal(address(token), charlie, MAX_STAKE);
    }

    function testFuzz_StakeAmount(uint256 amount) public {
        //ensures the fuzzed input stays within the staking limits
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        
        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_InterestCalculation(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 365 days);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        (,,, uint256 claimable) = staking.getUserInfo(alice);
        assertGt(claimable, 0);
    }

    function testFuzz_TierAssignment(uint256 amount) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        (, LayerEdgeStaking.Tier tier,,) = staking.getUserInfo(alice);
        assertTrue(uint8(tier) >= 1 && uint8(tier) <= 3);
    }

    function testFuzz_UnstakeAmount(uint256 stakeAmount, uint256 unstakeAmount) public {
        stakeAmount = bound(stakeAmount, MIN_STAKE, MAX_STAKE);
        unstakeAmount = bound(unstakeAmount, 1, stakeAmount);

        vm.startPrank(alice);
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        staking.unstake(unstakeAmount);
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, stakeAmount - unstakeAmount);
    }

    function testFuzz_APYUpdate(uint256 newAPY) public {
        newAPY = bound(newAPY, 1 * PRECISION, 100 * PRECISION);

        vm.startPrank(admin);
        staking.updateTierAPY(LayerEdgeStaking.Tier.Tier1, newAPY);
        vm.stopPrank();

        assertEq(staking.tier1APY(), newAPY);
    }

    function testFuzz_Compounding(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 30 days);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        vm.startPrank(alice);
        staking.compoundInterest();
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertGe(stakedAmount, amount);
    }

    function testFuzz_NativeStaking(uint256 amount) public {
        amount = bound(amount, 1 ether, 10 ether);

        vm.deal(alice, amount);
        vm.prank(alice);
        staking.stakeNative{value: amount}();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_MultipleUsers(uint8 userCount) public {
        userCount = uint8(bound(userCount, 1, 10));
        uint256 amount = MIN_STAKE;

        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
        }

        (uint256 tier1Count, uint256 tier2Count, uint256 tier3Count) = staking.getTierCounts();
        assertEq(tier1Count + tier2Count + tier3Count, userCount);
    }

    function testFuzz_EdgeCases(uint256 amount) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        
        // Test unstaking everything
        staking.unstake(amount);
        vm.stopPrank();

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, 0);
    }

    function testFuzz_TierBoundaries(uint8 initialUsers, uint8 additionalUsers) public {
        initialUsers = uint8(bound(initialUsers, 1, 5));
        additionalUsers = uint8(bound(additionalUsers, 0, 5));
        uint256 amount = MIN_STAKE;

        // create initial users
        for (uint8 i = 0; i < initialUsers; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
        }

        (uint256 tier1CountBefore,,) = staking.getTierCounts();

        // add more users
        for (uint8 i = 0; i < additionalUsers; i++) {
            address user = makeAddr(string(abi.encodePacked("newUser", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
        }

        (uint256 tier1CountAfter,,) = staking.getTierCounts();
        assertGe(tier1CountAfter, tier1CountBefore);
    }
}