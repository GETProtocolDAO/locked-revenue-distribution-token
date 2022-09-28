// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";
import "src/interfaces/IGovernanceLockedRevenueDistributionToken.sol";

contract TotalSupplyTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(alice);
        vault.delegate(alice);
    }

    function testGetPastTotalSupplyBlockNumberGTCurrentBlock() public {
        vm.expectRevert("GLRDT:BLOCK_NOT_MINED");
        vault.getPastTotalSupply(2);
    }

    function testGetPastTotalSupplyNoCheckpoints() public {
        assertEq(vault.getPastTotalSupply(0), 0);
    }

    function testGetPastTotalSupplyLatestBlockGTLastCheckpoint() public {
        mint(alice, mintAmount);

        vm.roll(block.number + 2); // block.number = 3

        assertEq(vault.getPastTotalSupply(1), mintAmount);
        assertEq(vault.getPastTotalSupply(2), mintAmount);
    }

    function testGetPastTotalSupplyBlockNumberLTFirstCheckpointBlock() public {
        vm.roll(block.number + 1);
        mint(alice, mintAmount);

        vm.roll(block.number + 2); // block.number = 3

        assertEq(vault.getPastTotalSupply(1), 0);
        assertEq(vault.getPastTotalSupply(2), mintAmount);
    }

    function testGetPastTotalSupply() public {
        vm.roll(block.number + 1); // block.number = 2
        mint(alice, mintAmount);

        vm.roll(block.number + 2); // block.number = 4
        burn(alice, 10);

        vm.roll(block.number + 2); // block.number = 6
        burn(alice, 10);

        vm.roll(block.number + 2); // block.number = 8
        mint(alice, 20);

        vm.roll(block.number + 2); // block.number = 10

        assertEq(vault.getPastTotalSupply(1), 0);
        assertEq(vault.getPastTotalSupply(2), mintAmount);
        assertEq(vault.getPastTotalSupply(3), mintAmount);
        assertEq(vault.getPastTotalSupply(4), mintAmount - 10);
        assertEq(vault.getPastTotalSupply(5), mintAmount - 10);
        assertEq(vault.getPastTotalSupply(6), mintAmount - 20);
        assertEq(vault.getPastTotalSupply(7), mintAmount - 20);
        assertApproxEqAbs(vault.getPastTotalSupply(8), mintAmount, 1);
    }
}
