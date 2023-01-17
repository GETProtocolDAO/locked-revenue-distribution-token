// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";

contract RewardsTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    function testRewardsAccountedFor() public {
        // Setup Alice as a depositor before rewards are distributed.
        mint(alice, mintAmount);
        vm.prank(alice);
        vault.delegate(alice);
        assertEq(vault.getVotes(alice), vault.balanceOfAssets(alice));

        // Distribute 0.1 ether worth of rewards to Alice.
        asset.mint(address(vault), 0.1 ether);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 weeks);
        assertEq(vault.balanceOfAssets(alice), 1.1 ether - 1); // Rounds down.

        // Alice's voting power is currently unchanged, this is expected because Alice remains to be the only voter so her
        // share of the total voting power remains the same.
        assertEq(vault.getVotes(alice), mintAmount);
        assertFalse(vault.getVotes(alice) == vault.balanceOfAssets(alice));

        // Bob now deposits 1 ether at the current rate.
        mint(bob, mintAmount);
        vm.prank(bob);
        vault.delegate(bob);
        assertEq(vault.getVotes(bob), vault.balanceOfAssets(bob));

        // Alice's voting power will now have updated to include her rewards at the time of Bob's deposit, meaning that
        // both Alice and Bob have accurate voting power to each other when the block was mined.
        vm.roll(block.number + 1);
        assertEq(vault.getVotes(alice), vault.balanceOfAssets(alice));
        assertEq(vault.getPastVotes(alice, block.number - 1), vault.balanceOfAssets(alice));
        assertEq(vault.getVotes(bob), vault.balanceOfAssets(bob));
        assertEq(vault.getPastVotes(bob, block.number - 1), vault.balanceOfAssets(bob));
    }
}
