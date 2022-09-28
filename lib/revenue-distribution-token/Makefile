.PHONY: diff
diff:
	@curl --silent https://raw.githubusercontent.com/maple-labs/revenue-distribution-token/v1.0.1/contracts/RevenueDistributionToken.sol | git diff --no-index - contracts/RevenueDistributionToken.sol; [ $$? -eq 1 ]