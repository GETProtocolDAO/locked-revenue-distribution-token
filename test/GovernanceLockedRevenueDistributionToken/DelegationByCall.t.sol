// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";
import "erc20/interfaces/IERC20.sol";

contract DelegationByCallTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    function testSetDelegationWithBalance() public {
        mint(alice, mintAmount);

        assertEq(vault.delegates(alice), address(0));

        vm.startPrank(alice);

        vm.expectEmit(true, true, true, true, address(vault));
        emit DelegateChanged(alice, address(0), alice);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(alice, 0, mintAmount);
        vault.delegate(alice);

        assertEq(vault.delegates(alice), alice);
        assertEq(vault.getVotes(alice), vault.convertToAssets(mintAmount));
        assertEq(vault.getPastVotes(alice, block.number - 1), 0);
        assertEq(vault.getPriorVotes(alice, block.number - 1), 0);

        // mine another block
        vm.roll(block.number + 1);

        // assert alice's voting power in previous block
        assertEq(vault.getPastVotes(alice, block.number - 1), vault.convertToAssets(mintAmount));
        assertEq(vault.getPriorVotes(alice, block.number - 1), vault.convertToAssets(mintAmount));

        vm.stopPrank();
    }

    function testSetDelegationWithoutBalance() public {
        assertEq(vault.delegates(alice), address(0));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(vault));
        emit DelegateChanged(alice, address(0), alice);
        vault.delegate(alice);

        assertEq(vault.delegates(alice), alice);
    }

    function testDelegationWithVaryingShareToAssetRatio() public {
        mint(alice, mintAmount);
        mint(bob, mintAmount);
        mint(eve, mintAmount);
        mint(recipient, mintAmount);

        vm.prank(alice);
        vault.delegate(alice);

        // share:asset = 1:1
        assertEq(vault.getVotes(alice), mintAmount);
        assertEq(vault.getVotes(alice), vault.convertToAssets(mintAmount));

        vm.startPrank(bob);
        vault.delegate(bob);
        vault.withdraw(0.5 ether, bob, bob); // change share to asset ratio
        vm.stopPrank();

        // share:asset != 1:1
        assertFalse(vault.getVotes(alice) == mintAmount);
        assertEq(vault.getVotes(alice), vault.convertToAssets(mintAmount));

        vm.roll(block.number + 1);

        vm.startPrank(eve);
        vault.delegate(eve);
        vault.withdraw(0.5 ether, eve, eve); // change share to asset ratio agian
        vm.stopPrank();

        // share:asset != 1:1
        assertFalse(vault.getVotes(alice) == vault.getPastVotes(alice, block.number - 1));
        assertEq(vault.getVotes(alice), vault.convertToAssets(mintAmount));

        vm.roll(block.number + 1);

        uint256 aliceVotes_ = vault.getVotes(alice);
        uint256 bobVotes_ = vault.getVotes(bob);
        uint256 eveVotes_ = vault.getVotes(eve);

        vm.prank(recipient);
        vault.withdraw(0.5 ether, recipient, recipient);
        vm.stopPrank();

        assertFalse(vault.getVotes(alice) == aliceVotes_);
        assertFalse(vault.getVotes(bob) == bobVotes_);
        assertFalse(vault.getVotes(eve) == eveVotes_);

        assertEq(vault.getVotes(alice), vault.convertToAssets(mintAmount));
        assertEq(vault.getVotes(bob), vault.convertToAssets(vault.balanceOf(bob)));
        assertEq(vault.getVotes(eve), vault.convertToAssets(vault.balanceOf(eve)));
    }

    function testChangeDelegation() public {
        mint(alice, mintAmount);
        vm.startPrank(alice);
        vault.delegate(alice);

        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true, address(vault));
        emit DelegateChanged(alice, alice, delegatee);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(alice, mintAmount, 0);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(delegatee, 0, mintAmount);
        vault.delegate(delegatee);

        assertEq(vault.delegates(alice), delegatee);
        assertEq(vault.getVotes(alice), 0);

        // assert alice's voting power in previous block
        assertEq(vault.getPastVotes(alice, block.number - 1), vault.convertToAssets(mintAmount));
        assertEq(vault.getPriorVotes(alice, block.number - 1), vault.convertToAssets(mintAmount));

        // assert delegatee's voting power in previous block
        assertEq(vault.getPastVotes(delegatee, block.number - 1), 0);
        assertEq(vault.getPriorVotes(delegatee, block.number - 1), 0);

        // mine another block
        vm.roll(block.number + 1);

        // assert alice's voting power in the last block
        assertEq(vault.getPastVotes(alice, block.number - 1), 0);
        assertEq(vault.getPriorVotes(alice, block.number - 1), 0);

        // assert delegatee's voting power in the last block
        assertEq(vault.getPastVotes(delegatee, block.number - 1), vault.convertToAssets(mintAmount));
        assertEq(vault.getPriorVotes(delegatee, block.number - 1), vault.convertToAssets(mintAmount));
    }
}
