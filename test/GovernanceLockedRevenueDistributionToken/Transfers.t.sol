// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";

contract TransfersTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    uint256 aliceVotes;
    uint256 recipientVotes;

    function setUp() public override {
        super.setUp();
        mint(alice, mintAmount);
    }

    function _afterEach() internal {
        assertEq(vault.getVotes(alice), aliceVotes);
        assertEq(vault.getVotes(recipient), recipientVotes);

        uint256 blockNumber_ = block.number;
        vm.roll(blockNumber_ + 2);
        assertEq(vault.getPastVotes(alice, blockNumber_), aliceVotes);
        assertEq(vault.getPastVotes(recipient, blockNumber_), recipientVotes);
        assertEq(vault.getPriorVotes(alice, blockNumber_), aliceVotes);
        assertEq(vault.getPriorVotes(recipient, blockNumber_), recipientVotes);
    }

    function testTransferWithNoDelegation() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Transfer(alice, recipient, 1);
        vault.transfer(recipient, 1);

        aliceVotes = 0;
        recipientVotes = 0;

        _afterEach();
    }

    function testTransferWithSenderDelegation() public {
        vm.startPrank(alice);
        vault.delegate(alice);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Transfer(alice, recipient, 1);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(alice, mintAmount, 1 ether - 1);
        vault.transfer(recipient, 1);
        vm.stopPrank();

        aliceVotes = mintAmount - 1;
        recipientVotes = 0;
        _afterEach();
    }

    function testTransferWithReceiverDelegation() public {
        vm.prank(recipient);
        vault.delegate(recipient);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(vault));
        emit Transfer(alice, recipient, 1);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(recipient, 0, 1);
        vault.transfer(recipient, 1);

        aliceVotes = 0;
        recipientVotes = 1;
        _afterEach();
    }

    function testTransferWithFullDelegation() public {
        vm.prank(alice);
        vault.delegate(alice);
        vm.prank(recipient);
        vault.delegate(recipient);

        vm.prank(alice);
        emit Transfer(alice, recipient, 1);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(alice, mintAmount, mintAmount - 1);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(recipient, 0, 1);
        vault.transfer(recipient, 1);

        aliceVotes = mintAmount - 1;
        recipientVotes = 1;
        _afterEach();
    }
}
