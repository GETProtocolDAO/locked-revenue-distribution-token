// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";

contract MetadataTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    function testInitialNonce(address user_) public {
        assertEq(vault.nonces(user_), 0);
    }

    function testDomainSeparator() public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                address(vault)
            )
        );
        assertEq(vault.DOMAIN_SEPARATOR(), domainSeparator);
    }

    function testRecentCheckpoints(uint256 rounds_) public {
        vm.assume(rounds_ > 1 && rounds_ < 5);
        vm.prank(alice);
        vault.delegate(alice);

        for (uint256 i_ = 0; i_ < rounds_; i_++) {
            mint(alice, 1 ether);

            (uint32 fromBlock_, uint96 votes_) = vault.checkpoints(alice, uint32(i_));
            assertEq(fromBlock_, block.number);
            assertEq(votes_, 1 ether * i_); // Checkpoint is one value behind current.
            assertEq(vault.getCurrentVotes(alice), 1 ether * (i_ + 1)); // Current.

            vm.roll(block.number + 1);
        }

        assertEq(vault.numCheckpoints(alice), rounds_);
    }
}
