// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "src/GovernanceLockedRevenueDistributionToken.sol";
import "../mocks/MockERC20.sol";

abstract contract GovernanceLockedRevenueDistributionTokenBaseTest is Test {
    // accounts
    address immutable alice = vm.addr(0x0A11CE);
    address immutable bob = vm.addr(0x0B0B);
    address immutable eve = vm.addr(0x0E5E);
    address immutable recipient = vm.addr(0x02);
    address immutable delegatee = vm.addr(0x03);

    // metadata
    string constant name = "xASSET";
    string constant symbol = "xASSET";
    string constant version = "1";
    uint256 immutable chainId = block.chainid;

    uint256 constant lockTime = 26 weeks;
    uint256 constant start = 10000000;
    uint256 constant mintAmount = 1 ether;

    GovernanceLockedRevenueDistributionToken vault;
    MockERC20 asset;

    event Transfer(address indexed owner_, address indexed recipient_, uint256 amount_);

    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    function setUp() public virtual {
        asset = new MockERC20("Underlying Asset", "ASSET");
        vault = new GovernanceLockedRevenueDistributionToken(
            name,
            symbol,
            address(this),
            address(asset),
            type(uint112).max,
            10,
            26 weeks,
            0
        );
        vm.warp(start); // Warp to non-zero timestamp
    }

    function mint(address account_, uint256 amount_) public {
        asset.mint(account_, amount_);
        vm.startPrank(account_);
        asset.approve(address(vault), amount_);
        vault.deposit(amount_, account_);
        vm.stopPrank();
    }

    function burn(address account_, uint256 amount_) public {
        vm.prank(account_);
        vault.redeem(amount_, account_, account_);
    }
}
