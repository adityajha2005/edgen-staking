// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LayerEdgeStaking} from "@src/stake/LayerEdgeStaking.sol";
import {LayerEdgeToken} from "@test/mock/LayerEdgeToken.sol";
import {DeployLayerEdgeStaking} from "@script/DeployLayerEdgeStaking.s.sol";
import {NetworkConfig, HelperConfig} from "@script/HelperConfig.s.sol";

contract InvariantFuzzTest is Test {
    LayerEdgeStaking public staking;
    LayerEdgeToken public token;
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
        // staking.setCompoundingStatus(false);
        staking.setCompoundingStatus(true);
        staking.setMinStakeAmount(MIN_STAKE);
        vm.stopPrank();

        deal(address(token), alice, MAX_STAKE);
        deal(address(token), bob, MAX_STAKE);
        deal(address(token), charlie, MAX_STAKE);
    }

    function testFuzz_TierCountsSum(uint8 userCount) public {
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

    function testFuzz_BalanceConsistency(uint8 userCount, uint256 amount) public {
        userCount = uint8(bound(userCount, 1, 5));
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        uint256 totalStaked = 0;
        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
            
            totalStaked += amount;
        }

        assertEq(staking.totalStaked(), totalStaked);
    }

    function testFuzz_InterestNonNegative(uint8 userCount, uint256 amount, uint256 timeElapsed) public {
        userCount = uint8(bound(userCount, 1, 5));
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 30 days);

        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + timeElapsed);

        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            (,,, uint256 claimable) = staking.getUserInfo(user);
            assertGe(claimable, 0);
        }
    }

    function testFuzz_APYBounds(uint256 tier1APY, uint256 tier2APY, uint256 tier3APY) public {
        tier1APY = bound(tier1APY, 1 * PRECISION, 100 * PRECISION);
        tier2APY = bound(tier2APY, 1 * PRECISION, 100 * PRECISION);
        tier3APY = bound(tier3APY, 1 * PRECISION, 100 * PRECISION);

        vm.startPrank(admin);
        staking.updateTierAPY(LayerEdgeStaking.Tier.Tier1, tier1APY);
        staking.updateTierAPY(LayerEdgeStaking.Tier.Tier2, tier2APY);
        staking.updateTierAPY(LayerEdgeStaking.Tier.Tier3, tier3APY);
        vm.stopPrank();

        assertEq(staking.tier1APY(), tier1APY);
        assertEq(staking.tier2APY(), tier2APY);
        assertEq(staking.tier3APY(), tier3APY);
    }

    function testFuzz_CompoundingBeneficial(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 30 days);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        (uint256 beforeStaked,,,) = staking.getUserInfo(alice);
        vm.prank(alice);
        staking.compoundInterest();
        (uint256 afterStaked,,,) = staking.getUserInfo(alice);

        assertGe(afterStaked, beforeStaked);
    }

    function testFuzz_UnstakeCompletion(uint256 amount, uint256 unstakeAmount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        unstakeAmount = bound(unstakeAmount, 1, amount);
        timeElapsed = bound(timeElapsed, 7 days, 30 days);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        staking.unstake(unstakeAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(alice);
        staking.completeUnstake(0);

        (uint256 stakedAmount,,,) = staking.getUserInfo(alice);
        assertEq(stakedAmount, amount - unstakeAmount);
    }

    function testFuzz_SystemStateConsistency(uint8 userCount, uint256 amount) public {
        userCount = uint8(bound(userCount, 1, 5));
        amount = bound(amount, MIN_STAKE, MAX_STAKE);

        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
        }

        // Check that all system invariants hold
        (uint256 tier1Count, uint256 tier2Count, uint256 tier3Count) = staking.getTierCounts();
        assertEq(tier1Count + tier2Count + tier3Count, userCount);
        assertEq(staking.totalStaked(), amount * userCount);
        assertGt(staking.rewardsReserve(), 0);
    }

    function testFuzz_TokenBalanceConsistency(uint8 userCount, uint256 amount) public {
        userCount = uint8(bound(userCount, 1, 3));
        amount = bound(amount, MIN_STAKE, MAX_STAKE / 10);

        uint256 totalStaked = 0;
        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();
            
            totalStaked += amount;
        }

        assertEq(token.balanceOf(address(staking)), totalStaked);
    }

    function testFuzz_InterestCalculationConsistency(uint256 amount, uint256 timeElapsed) public {
        amount = bound(amount, MIN_STAKE, MAX_STAKE);
        timeElapsed = bound(timeElapsed, 1 days, 30 days);

        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + timeElapsed);

        (,,, uint256 claimable) = staking.getUserInfo(alice);
        assertGt(claimable, 0);
    }

    function testFuzz_UserTierConsistency(uint8 userCount) public {
        userCount = uint8(bound(userCount, 1, 10));
        uint256 amount = MIN_STAKE;

        for (uint8 i = 0; i < userCount; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            deal(address(token), user, amount);
            
            vm.startPrank(user);
            token.approve(address(staking), amount);
            staking.stake(amount);
            vm.stopPrank();

            (, LayerEdgeStaking.Tier tier,,) = staking.getUserInfo(user);
            assertTrue(uint8(tier) >= 1 && uint8(tier) <= 3);
        }
    }
}