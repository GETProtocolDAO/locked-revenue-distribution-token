# Address and private key are Anvil defaults and are not safe. These should not
# be used on production networks.
FROM=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=http://127.0.0.1:8545
CHAIN_ID=1
PRECISION=`echo '2^96 - 1' | bc`
INSTANT_WITHDRAWAL_FEE=15
LOCK_TIME_WEEKS=26
INITIAL_SEED=1000000000000000000
VERIFY=1

.PHONY: myth
myth:
	@docker run --platform linux/amd64 -v $(shell pwd):/share -w /share mythril/myth analyze src/*.sol --solc-json mythril.config.json --solv 0.8.7

.PHONY: slither
slither:
	@docker run --platform linux/amd64 -v `pwd`:/share -w /share trailofbits/eth-security-toolbox -c 'solc-select use 0.8.7 && slither src/'

.PHONY: deploy-mockerc20
deploy-mockerc20:
	@forge create test/mocks/MockERC20.sol:MockERC20 \
		--rpc-url $(RPC_URL) \
		--from $(FROM) \
		--private-key $(PRIVATE_KEY) \
		--chain $(CHAIN_ID) \
		--constructor-args "$(NAME)" "$(SYMBOL)"

.PHONY: mint-mockerc20
mint-mockerc20:
	@cast send $(ASSET) "mint(address,uint256)" $(FROM) $(INITIAL_SEED) \
		--rpc-url $(RPC_URL) \
		--from $(FROM) \
		--private-key $(PRIVATE_KEY)

.PHONY: deploy-lrdt
deploy-lrdt:
	@cast send $(ASSET) "approve(address,uint256)" $$(cast compute-address $(FROM) --nonce $$(($$(cast nonce $(FROM)) + 1)) | sed 's/Computed Address: //') "$(INITIAL_SEED)" \
		--private-key $(PRIVATE_KEY)
	@forge create src/LockedRevenueDistributionToken.sol:LockedRevenueDistributionToken \
		--rpc-url $(RPC_URL) \
		--from $(FROM) \
		--private-key $(PRIVATE_KEY) \
		--chain $(CHAIN_ID) \
		$(if $(VERIFY == 1),--verify) \
		--constructor-args "$(NAME)" "$(SYMBOL)" "$(OWNER)" "$(ASSET)" $(PRECISION) $(INSTANT_WITHDRAWAL_FEE) $$(($(LOCK_TIME_WEEKS) * 7 * 24 * 60 * 60)) $(INITIAL_SEED)

.PHONY: deploy-glrdt
deploy-glrdt:
	@cast send $(ASSET) "approve(address,uint256)" $$(cast compute-address $(FROM) --nonce $$(($$(cast nonce $(FROM)) + 1)) | sed 's/Computed Address: //') "$(INITIAL_SEED)" \
		--private-key $(PRIVATE_KEY)
	@forge create src/GovernanceLockedRevenueDistributionToken.sol:GovernanceLockedRevenueDistributionToken \
		--rpc-url $(RPC_URL) \
		--from $(FROM) \
		--private-key $(PRIVATE_KEY) \
		--chain $(CHAIN_ID) \
		$(if $(VERIFY == 1),--verify) \
		--constructor-args "$(NAME)" "$(SYMBOL)" "$(OWNER)" "$(ASSET)" $(PRECISION) $(INSTANT_WITHDRAWAL_FEE) $$(($(LOCK_TIME_WEEKS) * 7 * 24 * 60 * 60)) $(INITIAL_SEED)