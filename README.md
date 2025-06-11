# LayerEdge Staking Protocol

A tiered staking smart contract system built on Solidity that provides different APY rates based on staking position using a first-come-first-serve model.

## Overview

The LayerEdge Staking Protocol implements a three-tier reward system:
- **Tier 1 (50% APY)**: First 20% of stakers
- **Tier 2 (35% APY)**: Next 30% of stakers  
- **Tier 3 (20% APY)**: Remaining 50% of stakers

Users are assigned tiers based on their joining order, incentivizing early participation.

## Features

- 🎯 **Tiered Rewards**: Different APY rates based on staking position
- 🔄 **Upgradeable**: UUPS proxy pattern for future improvements
- ⏰ **7-day Unstaking Window**: Security mechanism for withdrawals
- 🛡️ **Security**: Pausable, reentrancy protection, and access control
- 💰 **Native Token Support**: Stake both ERC20 tokens and native ETH (via WETH)
- 📊 **Interest Compounding**: Optional automatic interest compounding

## Deployment Networks

- **Base Sepolia Testnet**
- **Edgen Testnet**
- **Edgen Mainnet**

## Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm

### Installation
```bash
git clone <repository-url>
cd edgen-staking
forge install
```

### Build
```bash
make build
```

### Deploy
```bash
# Local development
make deploy-anvil

# Base Sepolia
make deploy-staking-base-sepolia

# Edgen networks
make deploy-staking-edgen-testnet
make deploy-staking-edgen-mainnet
```

## Architecture

- **LayerEdgeStaking.sol**: Main staking contract with tiered rewards
- **FenwickTree**: Efficient data structure for tier calculations
- **WETH9**: Wrapped ETH for native token staking support

## Environment Variables

Create a `.env` file with:
```
PRIVATE_KEY=your_private_key
BASE_SEPOLIA_RPC_URL=your_base_sepolia_rpc
EDGEN_RPC_URL=your_edgen_rpc
BASESCAN_API_KEY=your_basescan_api_key
```

## Testing

```bash
forge test
```

## License

MIT
