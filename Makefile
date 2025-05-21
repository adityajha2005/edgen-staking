-include .env

build:; forge build

anvil: anvil

deploy-anvil: 
	rm -rf out && forge script script/DeployLayerEdgeToken.s.sol:DeployLayerEdgeToken --rpc-url http://localhost:8545  \
		--private-key $(ANVIL_PRIVATE_KEY) --broadcast

deploy-base-sepolia: 
	rm -rf out && forge script script/DeployLayerEdgeToken.s.sol:DeployLayerEdgeToken --rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) --broadcast --verify
		--slow --etherscan-api-key $(BASE_SEPOLIA_API_KEY) -vvvv

deploy-weth9-base-sepolia:
	@rm -rf out && forge script script/DeployWETH9.s.sol:DeployWETH9 --rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) --broadcast --verify --slow --etherscan-api-key $(BASESCAN_API_KEY) -vvvv

deploy-layeredge-staking-base-sepolia:
	@rm -rf out && forge script script/DeployLayerEdgeStaking.s.sol:DeployLayerEdgeStaking --rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) --broadcast --verify --slow --etherscan-api-key $(BASESCAN_API_KEY) -vvvv

deploy-edgen-testnet:
	@rm -rf out && forge script script/DeployLayerEdgeToken.s.sol:DeployLayerEdgeToken --rpc-url $(EDGEN_RPC_URL) \
		--private-key $(EDGEN_KEY) --broadcast

deploy-weth9-edgen-testnet:
	@rm -rf out && forge script script/DeployWETH9.s.sol:DeployWETH9 --rpc-url $(EDGEN_RPC_URL) \
		--private-key $(EDGEN_KEY) --broadcast

deploy-staking-edgentestnet:
	@rm -rf out && forge script script/DeployLayerEdgeStaking.s.sol:DeployLayerEdgeStaking --rpc-url $(EDGEN_RPC_URL) \
		--private-key $(EDGEN_KEY) --broadcast

send-erc20:
	cast send 0x97b18CE4386Ad07296BC347C4bD33E4aC1b9e83a "transfer(address,uint256)" 0xe927b2f24Cc46345Ec2687B7b5dbCEC4e5e35f6e \
		100000000000000000000 --rpc-url $(EDGEN_RPC_URL) --private-key $(PRIVATE_KEY)

send-eth:
	cast send 0x8CB4783e150Fd71915Ea1D2277f264550e8784f4 --value 1000000000000000000 --gas-limit 21000 --rpc-url $(EDGEN_RPC_URL) --private-key $(EDGEN_KEY)
