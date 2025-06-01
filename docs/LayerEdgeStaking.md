# LayerEdgeStaking Contract Documentation

## Overview

The LayerEdgeStaking contract implements a tiered staking system for EDGEN tokens with different Annual Percentage Yield (APY) rates based on a user's staking position in the system. It operates on a first-come-first-serve model where early stakers receive higher rewards.

## Contract Features

- **Tiered Staking System**: Three tiers with different reward rates
- **Dynamic Tier Allocation**: Tiers determined by staking position and total active stakers
- **Reward Mechanisms**: Simple claiming or compounding options
- **Unstaking Rules**: Two-step unstaking process with a 7-day waiting period
- **Native Token Support**: Support for both ERC20 tokens and native tokens (via WETH wrapper)

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
- Last claim time
- Interest earned but not claimed
- Total claimed interest
- Join ID (position in the staking queue)
- Whether the user is active
- Whether the user is out of the tree (permanently in Tier 3)
- Whether the user's first deposit was more than minimum stake amount
- Tier change history
- Unstake requests

### Fenwick Tree Implementation

The contract uses a Fenwick Tree (Binary Indexed Tree) data structure to efficiently:
1. Track user rankings in the staking queue
2. Calculate tier boundaries
3. Handle tier transitions when users join or leave

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

1. User calls `stake(amount)` or `stakeNative()` function
2. Contract updates any pending interest
3. Tokens are transferred to the contract (or converted from native tokens)
4. If first time staking with more than minimum stake, user is assigned a join ID and added to the tree
5. If first time staking with less than minimum stake, user is marked as out of the tree and permanently assigned to Tier 3
6. User's balance and staking details are updated
7. User's tier is determined and recorded
8. Tier boundaries are checked and updated if necessary

### Unstaking Flow (Two-Step Process)

```
┌──────────┐     ┌───────────────┐     ┌────────────────┐
│  User    │     │ Check Unstake │     │ Update User's  │
│ Requests │────▶│ Eligibility   │────▶│ Interest       │
│ Unstake  │     │               │     │                │
└──────────┘     └───────────────┘     └────────────────┘
                                               │
                                               ▼
┌──────────────┐     ┌───────────────┐     ┌────────────────┐
│ Create       │     │ Check & Update│     │ Update User    │
│ Unstake      │◀────│ Tier          │◀────│ State & Balance│
│ Request      │     │ Boundaries    │     │                │
└──────────────┘     └───────────────┘     └────────────────┘
```

Then, after the 7-day waiting period:

```
┌──────────┐     ┌───────────────┐     ┌────────────────┐
│  User    │     │ Check Request │     │ Transfer EDGEN │
│ Completes│────▶│ Eligibility & │────▶│  to User       │
│ Unstake  │     │ Waiting Period│     │                │
└──────────┘     └───────────────┘     └────────────────┘
```

1. User calls `unstake(amount)` function
2. Contract checks that user has sufficient stake
3. Contract updates any pending interest
4. User's balance is reduced and staking details updated
5. If balance falls below minimum stake, user is marked as out of the tree and permanently assigned to Tier 3
6. Tier boundaries are checked and updated if necessary
7. An unstake request is created with timestamp
8. After 7 days, user calls `completeUnstake(index)` or `completeUnstakeNative(index)`
9. If waiting period has passed, tokens are transferred back to the user

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

The contract maintains a history of APY changes for each tier to ensure accurate interest calculations across APY changes.

### Tier Transitions

When users join or leave, tier boundaries may change, affecting other users. Let's look at some concrete examples:

#### Example 1: Adding a New User Without Tier Changes

```
           Before: 10 users                 After: 11 users
┌────────┬────────┬────────────┐   ┌────────┬────────┬────────────┐
│ Tier 1 │ Tier 2 │   Tier 3   │   │ Tier 1 │ Tier 2 │   Tier 3   │
│(2 users)│(3 users)│(5 users)  │   │(2 users)│(3 users)│(6 users)  │
└────────┴────────┴────────────┘   └────────┴────────┴────────────┘
  1  2    3  4  5   6  7  8  9 10    1  2    3  4  5   6  7  8  9 10 11
                                                          
```

In this example:
- Initially, there are 10 users with 2 in Tier 1, 3 in Tier 2, and 5 in Tier 3
- When the 11th user joins, they are added to Tier 3
- No existing user changes tiers because the tier boundaries remain at the same positions:
  - Tier 1: 20% of 11 = 2.2, rounded down to 2 users
  - Tier 2: 30% of 11 = 3.3, rounded down to 3 users
  - Tier 3: Remaining 6 users

#### Example 2: User Joining Causes Tier Promotion

```
           Before: 5 users                    After: 7 users
┌────────┬────────┬────────────┐   ┌────────┬────────┬────────────┐
│ Tier 1 │ Tier 2 │   Tier 3   │   │ Tier 1 │ Tier 2 │   Tier 3   │
│(1 user) │(1 user) │(3 users)  │   │(1 user) │(2 users)│(4 users)  │
└────────┴────────┴────────────┘   └────────┴────────┴────────────┘
   1       2         3  4  5         1        2  3      4  5  6  7
                                                 ↑
                                            User #3
                                        moves from Tier 3
                                            to Tier 2
```

In this example:
- With 5 users, the tier calculation works out to:
  - Tier 1: 20% of 5 = 1 user (User #1)
  - Tier 2: 30% of 5 = 1.5, rounded down to 1 user (User #2)
  - Tier 3: Remaining 3 users (Users #3, #4, #5)
- When both User #6 and User #7 join, the tier boundaries shift:
  - Tier 1: 20% of 7 = 1.4, rounded down to 1 user
  - Tier 2: 30% of 7 = 2.1, rounded down to 2 users
  - Tier 3: Remaining 4 users
- This causes:
  - User #1 remains in Tier 1
  - User #2 remains in Tier 2
  - User #3 moves from Tier 3 to Tier 2 (promotion)
  - Users #4 and #5 remain in Tier 3
  - Users #6 and #7 join as Tier 3

When a user joins or leaves, the contract:
1. Calculates new tier boundaries
2. Identifies any users crossing tier boundaries
3. Records tier changes for affected users

Note: When a user joins or leaves the system, at most two people's tier will be changed and the method `_checkBoundariesAndRecord` will find exactly whose tier is going to change and record them.

### Key points to note
- Any user who stakes more than `minStakeAmount` will be added to the tree/tier system. They might get promoted/demoted based on FCFS condition as mentioned above.
- Any user who stakes less than `minStakeAmount` will be in Tier3 permanently and out of the tree/tier system (won't get promoted) even if they stake more later.
- Any user who unstakes and if the balance goes less than `minStakeAmount` will also be moved out of the tree/tier system and will be in Tier 3 permanently.
- Any users who is out of the tree/system can stake more at any time but will only be earning interest at Tier3 APY.
- If compounding is enabled globally, all the users should be able to compound and earn interest with respect to their tier. This also includes users whose balance is less than `minStakeAmount` and in Tier3.

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

## Native Token Support

The contract supports both ERC20 token staking and native token staking:

- `stake(amount)` - For staking ERC20 tokens
- `stakeNative()` - For staking native tokens (automatically wrapped to WETH)
- `claimInterest()` - For claiming ERC20 token rewards
- `claimInterestNative()` - For claiming rewards as native tokens
- `completeUnstake(index)` - For completing unstaking of ERC20 tokens
- `completeUnstakeNative(index)` - For completing unstaking as native tokens

This dual support allows for flexibility in user interactions with the staking system.

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
- `Unstaked`: When a user completes unstaking tokens
- `UnstakedQueued`: When a user queues an unstake request
- `RewardClaimed`: When a user claims rewards
- `TierChanged`: When a user's tier changes
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
- `unstakeRequests`: Queue of unstake requests per user
- `stakerCountInTree`: Number of stakers in the tiering tree
- `stakerCountOutOfTree`: Number of stakers permanently in Tier 3
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

## Security Audit Considerations

### Critical Areas for Review

1. **Native Token Handling**
   - ETH/WETH conversion mechanisms
   - Receive and fallback function security
   - Native token balance tracking
   - Potential reentrancy in native token operations

2. **Tier System Security**
   - Fenwick Tree implementation correctness
   - Tier boundary calculation precision
   - Potential manipulation of tier positions
   - Race conditions in tier updates

3. **Reward Calculation**
   - Interest calculation precision
   - Potential overflow/underflow in calculations
   - APY history tracking accuracy
   - Compounding mechanism security

4. **Access Control**
   - Owner privileges and restrictions
   - Upgrade mechanism security (UUPS)
   - Emergency pause functionality
   - Admin function access controls

5. **Unstaking Process**
   - Two-step unstaking security
   - Waiting period enforcement
   - Request queue management

### Known Limitations

1. **Tier System**
   - Maximum of 100,000,000 users (MAX_USERS constant)
   - Tier percentages are fixed (20%, 30%, 50%)
   - Permanent tier downgrade after balance falls below minimum stake

2. **Staking Rules**
   - Minimum stake amount requirement
   - 7-day unstaking window
   - No partial unstaking restrictions
   - No maximum stake amount

3. **Reward System**
   - Rewards must be pre-deposited
   - No automatic reward distribution
   - Compounding can be disabled by admin

### Potential Attack Vectors

1. **Tier Manipulation**
   - Front-running tier changes
   - Batch staking/unstaking to manipulate tier boundaries
   - Potential for tier position gaming

2. **Reward Exploitation**
   - Flash loan attacks on reward calculations
   - Compounding timing attacks
   - Reward reserve manipulation

3. **Native Token Vulnerabilities**
   - ETH/WETH conversion attacks
   - Direct ETH transfer vulnerabilities
   - Potential balance tracking issues

Note: The staking contract will be deployed on Ethereum (or other EVMs) and on LayerEdge's L1 (EVM compatible). 
On Ethereum, the staking token will be a simple ERC20 contract (OpenZeppelin's implementation) of $EDGEN token (only $EDGEN).
On LayerEdge's L1, the staking token will be a WETH9 implementation, a wrapper of native token $EDGEN.

