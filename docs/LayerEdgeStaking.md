# LayerEdgeStaking Contract Documentation

## Overview

The LayerEdgeStaking contract implements a tiered staking system for EDGEN tokens with different Annual Percentage Yield (APY) rates based on a user's staking position in the system. It operates on a first-come-first-serve model where early stakers receive higher rewards.

## Contract Features

- **Tiered Staking System**: Three tiers with different reward rates
- **Dynamic Tier Allocation**: Tiers determined by staking position and total active stakers
- **Upgradeable Contract**: Uses OpenZeppelin's UUPS upgradeable pattern
- **Reward Mechanisms**: Simple claiming or compounding options
- **Unstaking Rules**: Unstaking window of 7 days and permanent tier downgrade after unstaking

## Core Components

### Tier System

The staking contract implements three tiers of stakers:

| Tier | Allocation | Default APY | Notes |
|------|------------|-------------|-------|
| Tier 1 | First 20% of stakers | 50% | Highest reward tier |
| Tier 2 | Next 30% of stakers | 35% | Medium reward tier |
| Tier 3 | Remaining 50% of stakers | 20% | Base reward tier |

The tier allocation is dynamically calculated based on the total number of active stakers. Users are assigned to tiers based on their position in the staking queue (determined by their join ID).

```
┌───────────────────────────────────────────────────────┐
│                     Active Stakers                     │
├──────────────────┬──────────────────┬─────────────────┤
│     Tier 1       │      Tier 2      │     Tier 3      │
│    (First 20%)   │    (Next 30%)    │  (Remaining)    │
│     50% APY      │     35% APY      │    20% APY      │
└──────────────────┴──────────────────┴─────────────────┘
       ↑                  ↑                   ↑
   Early stakers    Medium stakers       Late stakers
```

### User Information

For each staker, the contract tracks:

- Current staked balance
- Deposit time
- Last claim time
- Interest earned but not claimed
- Total claimed interest
- Join ID (position in the staking queue)
- Unstaking history
- Tier change history

### Fenwick Tree Implementation

The contract uses a Fenwick Tree (Binary Indexed Tree) data structure to efficiently:
1. Track user rankings in the staking queue
2. Calculate tier boundaries
3. Handle tier transitions when users join or leave

```
            Fenwick Tree Structure
            
            ┌─────┐
            │Root │
            └─────┘
           /       \
      ┌─────┐     ┌─────┐
      │Node1│     │Node2│
      └─────┘     └─────┘
     /     \     /     \
 ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
 │Leaf1│ │Leaf2│ │Leaf3│ │Leaf4│ ... (User positions)
 └─────┘ └─────┘ └─────┘ └─────┘
```

This allows for O(log n) time complexity for:
- Updating a user's status (join/leave)
- Finding the rank of a user
- Determining tier boundaries

## Core Workflows

### Staking Flow

```
┌──────────┐     ┌───────────────┐     ┌────────────────┐
│  User    │     │ Update User's │     │ Transfer EDGEN │
│ Stakes   │────▶│ Interest      │────▶│  to Contract   │
│  EDGEN   │     │               │     │                │
└──────────┘     └───────────────┘     └────────────────┘
                                               │
                                               ▼
┌──────────────┐     ┌───────────────┐     ┌────────────────┐
│Record User's │     │ Check & Update│     │ Register User  │
│Tier Change   │◀────│ Tier          │◀────│ If First Stake │
│              │     │ Boundaries    │     │                │
└──────────────┘     └───────────────┘     └────────────────┘
```

1. User calls `stake(amount)` function
2. Contract updates any pending interest
3. Tokens are transferred to the contract
4. If first time staking, user is assigned a join ID
5. User's balance and staking details are updated
6. User's tier is determined and recorded
7. Tier boundaries are checked and updated if necessary

### Unstaking Flow

```
┌──────────┐     ┌───────────────┐     ┌────────────────┐
│  User    │     │ Check Unstake │     │ Update User's  │
│ Unstakes │────▶│ Eligibility   │────▶│ Interest       │
│  EDGEN   │     │               │     │                │
└──────────┘     └───────────────┘     └────────────────┘
                                               │
                                               ▼
┌──────────────┐     ┌───────────────┐     ┌────────────────┐
│Transfer EDGEN│     │ Check & Update│     │ Update User    │
│  to User     │◀────│ Tier          │◀────│ State & Tier   │
│              │     │ Boundaries    │     │                │
└──────────────┘     └───────────────┘     └────────────────┘
```

1. User calls `unstake(amount)` function
2. Contract checks that user has sufficient stake and the unstaking window (7 days) has passed
3. Contract updates any pending interest
4. User's balance is reduced and staking details updated
5. User is marked as having unstaked, which permanently downgrades them to Tier 3
6. Tier boundaries are checked and updated if necessary
7. Tokens are transferred back to the user

### Interest Calculation & Claiming

```
┌──────────┐     ┌───────────────┐     ┌────────────────┐
│  User    │     │ Calculate     │     │ Transfer       │
│ Claims   │────▶│ Interest Based│────▶│ Rewards to     │
│ Interest │     │ on Tier & Time│     │ User           │
└──────────┘     └───────────────┘     └────────────────┘
```

Interest is calculated using the formula:
```
Interest = (Balance * APY * TimeStaked) / (SECONDS_IN_YEAR * PRECISION)
```

Where:
- Balance is the user's staked amount
- APY is the annual percentage yield for the user's tier (in basis points)
- TimeStaked is the duration since last claim in seconds
- SECONDS_IN_YEAR is 31,536,000 (365 days)
- PRECISION is 10^18 (to handle decimal calculations)

### Tier Transitions

When users join or leave, tier boundaries may change, affecting other users:

```
           Before: 10 users                 After: 11 users
┌────────┬────────┬────────────┐   ┌────────┬────────┬────────────┐
│ Tier 1 │ Tier 2 │   Tier 3   │   │ Tier 1 │ Tier 2 │   Tier 3   │
│(2 users)│(3 users)│(5 users)  │   │(2 users)│(3 users)│(6 users)  │
└────────┴────────┴────────────┘   └────────┴────────┴────────────┘
  1  2    3  4  5   6  7  8  9 10    1  2    3  4  5   6  7  8  9 10 11
                                                             ↑
                                                        New User
```

When a user joins or leaves, the contract:
1. Calculates new tier boundaries
2. Identifies any users crossing tier boundaries
3. Records tier changes for affected users

## Administrative Functions

### APY Management

The contract owner can:
- Update APY rates for individual tiers
- Update all APY rates at once
- The APY history is preserved for accurate interest calculations

### Contract Management

The owner can also:
- Pause/unpause the contract
- Set minimum stake amount (default: 3000 EDGEN)
- Enable/disable compounding
- Upgrade the contract implementation (UUPS pattern)
- Deposit or withdraw from the rewards reserve

## Rewards Management

```
┌────────────┐     ┌───────────────┐     ┌────────────────┐
│ Admin/User │     │ Transfer Tokens│     │ Update Rewards │
│ Deposits   │────▶│ to Contract   │────▶│ Reserve Balance│
│ Rewards    │     │               │     │                │
└────────────┘     └───────────────┘     └────────────────┘
```

Rewards can be deposited by:
- Contract owner
- External users/systems

Rewards are tracked in a separate `rewardsReserve` balance to ensure sufficient funds are available for claiming.

## Security Considerations

The contract implements several security measures:

- **Reentrancy Protection**: Uses OpenZeppelin's ReentrancyGuard
- **Pausable**: Can be paused in emergency situations
- **Access Control**: Admin functions restricted to owner
- **Unstaking Window**: 7-day minimum staking period before withdrawals
- **Rewards Reserve**: Separate tracking of reward funds

## Events

The contract emits the following events:

- `Staked`: When a user stakes tokens
- `Unstaked`: When a user unstakes tokens
- `RewardClaimed`: When a user claims rewards
- `TierDowngraded`: When a user's tier is downgraded
- `APYUpdated`: When APY rates are updated
- `RewardsDeposited`: When rewards are deposited

## Constants

- `SECONDS_IN_YEAR`: 31,536,000 (365 days)
- `PRECISION`: 10^18 (for decimal calculations)
- `UNSTAKE_WINDOW`: 604,800 (7 days)
- `MAX_USERS`: 100,000,000
- `TIER1_PERCENTAGE`: 20 (first 20% of stakers)
- `TIER2_PERCENTAGE`: 30 (next 30% of stakers)
- Default minimum stake: 3000 EDGEN tokens

## State Variables

- `tier1APY`, `tier2APY`, `tier3APY`: Current APY rates for tiers
- `stakingToken`: The EDGEN ERC20 token
- `users`: Mapping of user addresses to their staking information
- `stakerAddress`: Mapping of join IDs to staker addresses
- `stakerTierHistory`: History of tier changes for each user
- `activeStakerCount`: Total number of active stakers
- `totalStaked`: Total amount of tokens staked
- `rewardsReserve`: Available rewards balance
- `nextJoinId`: Next join ID to assign
- `minStakeAmount`: Minimum stake amount
- `compoundingEnabled`: Whether compounding is enabled
- `stakerTree`: Fenwick Tree for tracking staker positions

## Upgradeability

The contract uses OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) pattern:
- Logic contract can be upgraded while preserving state
- Upgrades can only be performed by the contract owner
- The `initialize` function replaces the constructor
