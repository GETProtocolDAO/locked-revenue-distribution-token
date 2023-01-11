// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";
import "src/interfaces/IGovernanceLockedRevenueDistributionToken.sol";

contract CompoundTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(alice);
        mint(alice, mintAmount);
        assertEq(vault.balanceOf(alice), mintAmount);
    }

    function testNumCheckpointsForDelegateCheckpoints() public {
        vm.prank(alice);
        vault.transfer(recipient, 100);
        assertEq(vault.numCheckpoints(bob), 0);

        vm.startPrank(recipient);
        vault.delegate(bob);
        assertEq(vault.numCheckpoints(bob), 1);

        vm.roll(block.number + 1); // block.number = 2
        vault.transfer(eve, 10);
        assertEq(vault.numCheckpoints(bob), 2);

        vm.roll(block.number + 1); // block.number = 3
        vault.transfer(eve, 10);
        assertEq(vault.numCheckpoints(bob), 3);

        vm.roll(block.number + 1); // block.number = 4
        vm.stopPrank();
        vm.prank(alice);
        vault.transfer(recipient, 20);
        assertEq(vault.numCheckpoints(bob), 4);

        vm.roll(block.number + 1); // block.number = 5

        assertEq(vault.getPastVotes(bob, 1), 100);
        assertEq(vault.getPastVotes(bob, 2), 90);
        assertEq(vault.getPastVotes(bob, 3), 80);
        assertEq(vault.getPastVotes(bob, 4), 100);
        assertEq(vault.getPriorVotes(bob, 1), 100);
        assertEq(vault.getPriorVotes(bob, 2), 90);
        assertEq(vault.getPriorVotes(bob, 3), 80);
        assertEq(vault.getPriorVotes(bob, 4), 100);
    }

    function testNumCheckpointsForValidCheckpointAddition() public {
        vm.prank(alice);
        vault.transfer(recipient, 100);
        assertEq(vault.numCheckpoints(bob), 0);

        vm.startPrank(recipient);
        vault.delegate(bob);
        vault.transfer(eve, 10);
        vault.transfer(eve, 10);

        assertEq(vault.numCheckpoints(bob), 1);

        (uint32 fromBlock_, uint96 votes_) = vault.checkpoints(bob, 0);
        assertEq(fromBlock_, 1);
        assertEq(votes_, vault.convertToAssets(80));
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.prank(alice);
        vault.transfer(recipient, 20);

        assertEq(vault.numCheckpoints(bob), 2);

        (fromBlock_, votes_) = vault.checkpoints(bob, 1);
        assertEq(fromBlock_, 2);
        assertEq(votes_, vault.convertToAssets(100));
    }

    function testGetPastVotesBlockNumberGTCurrentBlock() public {
        vm.expectRevert("GLRDT:BLOCK_NOT_MINED");
        vault.getPastVotes(bob, 2);
        vm.expectRevert("GLRDT:BLOCK_NOT_MINED");
        vault.getPriorVotes(bob, 2);
    }

    function testGetPastVotesNoCheckpoints() public {
        assertEq(vault.getPastVotes(bob, 0), 0);
        assertEq(vault.getPriorVotes(bob, 0), 0);
    }

    function testGetPastVotesLatestBlockGTLastCheckpoint() public {
        vm.startPrank(alice);
        vault.delegate(bob);

        // mine 2 blocks
        vm.roll(block.number + 2);

        assertEq(vault.getPastVotes(bob, 1), mintAmount);
        assertEq(vault.getPastVotes(bob, 2), mintAmount);
        assertEq(vault.getPriorVotes(bob, 1), mintAmount);
        assertEq(vault.getPriorVotes(bob, 2), mintAmount);
    }

    function testGetPastVotesBlockNumberLTFirstCheckpointBlock() public {
        vm.roll(block.number + 1); // block.number = 2
        vm.prank(alice);
        vault.delegate(bob);

        vm.roll(block.number + 2); // block.number = 4

        assertEq(vault.getPastVotes(bob, 1), 0);
        assertEq(vault.getPastVotes(bob, 3), mintAmount);
        assertEq(vault.getPriorVotes(bob, 1), 0);
        assertEq(vault.getPriorVotes(bob, 3), mintAmount);
    }

    function testGetPastVotes() public {
        vm.roll(block.number + 1); // block.number = 2
        vm.startPrank(alice);
        vault.delegate(bob);

        vm.roll(block.number + 2); // block.number = 4
        vault.transfer(eve, 10);

        vm.roll(block.number + 2); // block.number = 6
        vault.transfer(eve, 10);
        vm.stopPrank();

        vm.roll(block.number + 2); // block.number = 8
        vm.prank(eve);
        vault.transfer(alice, 20);

        vm.roll(block.number + 2); // block.number = 10

        assertEq(vault.getPastVotes(bob, 1), 0);
        assertEq(vault.getPastVotes(bob, 2), mintAmount);
        assertEq(vault.getPastVotes(bob, 3), mintAmount);
        assertEq(vault.getPastVotes(bob, 4), mintAmount - 10);
        assertEq(vault.getPastVotes(bob, 5), mintAmount - 10);
        assertEq(vault.getPastVotes(bob, 6), mintAmount - 20);
        assertEq(vault.getPastVotes(bob, 7), mintAmount - 20);
        assertEq(vault.getPastVotes(bob, 8), mintAmount);
        assertEq(vault.getPastVotes(bob, 9), mintAmount);

        assertEq(vault.getPriorVotes(bob, 1), 0);
        assertEq(vault.getPriorVotes(bob, 2), mintAmount);
        assertEq(vault.getPriorVotes(bob, 3), mintAmount);
        assertEq(vault.getPriorVotes(bob, 4), mintAmount - 10);
        assertEq(vault.getPriorVotes(bob, 5), mintAmount - 10);
        assertEq(vault.getPriorVotes(bob, 6), mintAmount - 20);
        assertEq(vault.getPriorVotes(bob, 7), mintAmount - 20);
        assertEq(vault.getPriorVotes(bob, 8), mintAmount);
        assertEq(vault.getPriorVotes(bob, 9), mintAmount);
    }
}
