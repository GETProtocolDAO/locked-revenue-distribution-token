.PHONY: diff
diff:
	@curl --silent https://raw.githubusercontent.com/maple-labs/erc20/v1.0.0/contracts/ERC20.sol | git diff --no-index - contracts/ERC20.sol; [ $$? -eq 1 ]
	@curl --silent https://raw.githubusercontent.com/maple-labs/erc20/v1.0.0/contracts/interfaces/IERC20.sol | git diff --no-index - contracts/interfaces/IERC20.sol; [ $$? -eq 1 ]