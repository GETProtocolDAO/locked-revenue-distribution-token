// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";

contract LockingTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    uint256 aliceVotes;
    uint256 vaultVotes;

    function setUp() public override {
        super.setUp();
        mint(alice, mintAmount);
    }

    function _afterEach() internal {
        assertEq(vault.getVotes(alice), aliceVotes);
        assertEq(vault.getVotes(address(vault)), vaultVotes);

        uint256 blockNumber_ = block.number;
        vm.roll(blockNumber_ + 2);
        assertEq(vault.getPastVotes(alice, blockNumber_), aliceVotes);
        assertEq(vault.getPastVotes(address(vault), blockNumber_), vaultVotes);
        assertEq(vault.getPriorVotes(alice, blockNumber_), aliceVotes);
        assertEq(vault.getPriorVotes(address(vault), blockNumber_), vaultVotes);
    }

    function testCreateWithdrawalRequestWithNoDelegation() public {
        vm.prank(alice);
        vault.createWithdrawalRequest(0.5 ether);

        aliceVotes = 0;
        vaultVotes = 0;

        _afterEach();
    }

    function testCreateWithdrawalRequestWithSenderDelegation() public {
        vm.startPrank(alice);
        vault.delegate(alice);
        vault.createWithdrawalRequest(0.5 ether);

        aliceVotes = mintAmount - 0.5 ether;
        vaultVotes = 0;

        _afterEach();
    }

    function testCancelWithdrawalRequestWithNoDelegation() public {
        vm.startPrank(alice);
        vault.createWithdrawalRequest(0.5 ether);
        vault.cancelWithdrawalRequest(0);

        aliceVotes = 0;
        vaultVotes = 0;

        _afterEach();
    }

    function testCancelWithdrawalRequestWithSenderDelegation() public {
        vm.startPrank(alice);
        vault.delegate(alice);
        vault.createWithdrawalRequest(0.5 ether);
        vault.cancelWithdrawalRequest(0);

        aliceVotes = 1 ether;
        vaultVotes = 0;

        _afterEach();
    }

    function testExecuteWithdrawalRequestWithNoDelegation() public {
        vm.startPrank(alice);
        vault.createWithdrawalRequest(0.5 ether);
        vault.executeWithdrawalRequest(0);

        aliceVotes = 0;
        vaultVotes = 0;

        _afterEach();
    }

    function testExecuteWithdrawalRequestWithSenderDelegation() public {
        vm.startPrank(alice);
        vault.delegate(alice);
        vault.createWithdrawalRequest(0.5 ether);
        vault.executeWithdrawalRequest(0);

        aliceVotes = mintAmount - 0.5 ether;
        vaultVotes = 0 ether;

        _afterEach();
    }
}
