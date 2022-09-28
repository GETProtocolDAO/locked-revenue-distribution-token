# ERC20

Based on [Maple Lab's ERC20 v1.0.0](https://github.com/maple-labs/erc20/tree/v1.0.0).

## Changes

See diff using `make diff`.

### 1. Virtual `_mint`, `_burn`, `_transfer`

GovernanceLockedRevenueDistributionToken overrides these internal functions to move voting power when share tokens are moved. These have been made virtual to allow for these overrides.

### 2. Chain ID Validation on Permit

Raised as `TOB-MPL-01` in the [Trail of Bits Audit of Maple's contracts](https://github.com/maple-labs/revenue-distribution-token/#audit-reports), the ERC20 permit implementation may be vulnerable to replay attacks in the case of a chain hard fork. This has been negated by computing the DOMAIN_SEPARATOR when `block.chainId` does not match the `chainId` stored within the constructor.

Uses [Solmate's ERC20 v6](https://github.com/transmissions11/solmate/blob/v6/src/tokens/ERC20.sol#L152) implementation.

### 3. Private PERMIT_TYPEHASH

Raised as `L-05` in the [Code 4rena Audit](https://code4rena.com/reports/2022-03-maple/#l-05-ierc20-incorrectly-includes-permit_typehash), PERMIT_TYPEHASH should not be public and included in the interface. The variable scope has been changed to private.
