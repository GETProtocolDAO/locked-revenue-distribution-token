# RevenueDistributionToken

Based on [Maple Lab's RevenueDistributionToken v1.0.1](https://github.com/maple-labs/revenue-distribution-token/tree/v1.0.1).

## Changes

See diff using `make diff`.

### 1. Public `deposit`, `mint`

To support reuse of the slippage-protected ERC5143 deposit and mint functions implemented in LRDT, the deposit and mint functions of RDT have been made public.
