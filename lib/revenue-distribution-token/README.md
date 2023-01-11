# RevenueDistributionToken

Based on [Maple Lab's RevenueDistributionToken v1.0.1](https://github.com/maple-labs/revenue-distribution-token/tree/v1.0.1).

## Changes

See diff using `make diff`.

### 1. Public `deposit`, `mint`

To support reuse of the slippage-protected ERC5143 deposit and mint functions implemented in LRDT, the deposit and mint functions of RDT have been made public.

### 2. Virtual `_mint`, `_burn`

The lack of virtual modifier on the `_mint` and `_burn` function within RDT prevent these from being overridden. This was required within GLRDT to write checkpoints after minting new shares.
