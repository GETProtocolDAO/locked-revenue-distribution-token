// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./LockedRevenueDistributionTokenBaseTest.t.sol";

contract UpdateVestingScheduleTest is LockedRevenueDistributionTokenBaseTest {
    function testCannotUpdateVestingScheduleZeroSupply() public {
        vm.expectRevert("LRDT:UVS:ZERO_SUPPLY");
        vault.updateVestingSchedule();
    }

    function testCannotUpdateVestingScheduleZeroIssuanceRate() public {
        _setUpDepositor(alice, 1 ether);
        vm.expectRevert("LRDT:UVS:ZERO_ISSUANCE_RATE");
        vault.updateVestingSchedule();
    }

    function testUpdateVestingScheduleAsNonOwner() public {
        vm.startPrank(alice);
        asset.mint(alice, 1 ether);
        asset.approve(address(vault), 1 ether);
        vault.deposit(1 ether, alice);
        vm.stopPrank();

        asset.mint(address(vault), 0.5 ether);

        vm.prank(alice);
        vault.updateVestingSchedule();
        assertEq(vault.vestingPeriodFinish(), block.timestamp + 2 weeks);

        vm.warp(block.timestamp + 2 weeks);
        vm.prank(bob);
        vault.updateVestingSchedule();
        assertEq(vault.vestingPeriodFinish(), block.timestamp + 2 weeks);

        vm.warp(block.timestamp + 2 weeks);
        vm.prank(alice);
        vault.updateVestingSchedule();
        assertEq(vault.vestingPeriodFinish(), block.timestamp + 2 weeks);
    }

    function testUpdateVestingScheduleStillVesting() public {
        vm.startPrank(alice);
        asset.mint(alice, 1 ether);
        asset.approve(address(vault), 1 ether);
        vault.deposit(1 ether, alice);
        asset.mint(address(vault), 0.5 ether);

        vault.updateVestingSchedule();
        assertEq(vault.vestingPeriodFinish(), block.timestamp + 2 weeks);

        vm.warp(block.timestamp + 2 weeks - 25 hours);
        vm.expectRevert("LRDT:UVS:STILL_VESTING");
        vault.updateVestingSchedule();

        vm.warp(block.timestamp + 1 hours);
        vault.updateVestingSchedule();
        assertEq(vault.vestingPeriodFinish(), block.timestamp + 2 weeks);
    }
}
