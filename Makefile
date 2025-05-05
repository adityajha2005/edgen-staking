-include .env

build:; forge build

anvil: anvil

deploy-anvil: 
	rm -rf out && forge script script/DeployLayerEdgeToken.s.sol:DeployLayerEdgeToken --rpc-url http://localhost:8545  \
		--private-key $(ANVIL_PRIVATE_KEY) --broadcast

deploy-base-sepolia: 
	rm -rf out && forge script script/DeployLayerEdgeToken.s.sol:DeployLayerEdgeToken --rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) --broadcast --verify
		--slow --etherscan-api-key $(BASE_SEPOLIA_API_KEY) -vvvv
