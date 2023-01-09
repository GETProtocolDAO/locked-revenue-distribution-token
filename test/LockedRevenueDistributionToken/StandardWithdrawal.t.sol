// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./LockedRevenueDistributionTokenBaseTest.t.sol";
import {ILockedRevenueDistributionToken} from "src/interfaces/ILockedRevenueDistributionToken.sol";

contract StandardWithdrawalTest is LockedRevenueDistributionTokenBaseTest {
    function testSetLockTime(uint256 lockTime_) public {
        lockTime_ = bound(lockTime_, 0, 104 weeks);
        vault.setLockTime(lockTime_);
        assertEq(vault.lockTime(), lockTime_);
    }

    function testCannotSetLockTimeAboveBound() public {
        vm.expectRevert("LRDT:INVALID_LOCK_TIME");
        vault.setLockTime(104 weeks + 1);
    }

    function testCannotCreateWithdrawalRequestZeroShares() public {
        _setUpDepositor(alice, 1 ether);
        vm.expectRevert("LRDT:INVALID_AMOUNT");
        vault.createWithdrawalRequest(0);
    }

    function testCannotCreateWithdrawalRequestNoDeposit() public {
        vm.expectRevert("LRDT:INSUFFICIENT_BALANCE");
        vm.prank(alice);
        vault.createWithdrawalRequest(1 ether);
    }

    function testCannotCreateWithdrawalRequestTooManyShares(uint256 assets_) public {
        assets_ = bound(assets_, 2, type(uint96).max);

        _setUpDepositor(alice, assets_);
        uint256 shares_ = vault.balanceOf(alice);

        vm.expectRevert("LRDT:INSUFFICIENT_BALANCE");
        vault.createWithdrawalRequest(shares_ + 1);
    }

    function testCannotExecuteOutsideOfWithdrawalWindow() public {
        _setUpDepositor(alice, 1 ether);
        vault.createWithdrawalRequest(1 ether);
        vm.warp(block.timestamp + vault.lockTime() + vault.WITHDRAWAL_WINDOW());

        vm.expectRevert("LRDT:WITHDRAWAL_WINDOW_CLOSED");
        vault.executeWithdrawalRequest(0);
    }

    function testCreateMultipleWithdrawalRequests() public {
        _setUpDepositor(alice, 1 ether);

        // Creates first withdrawal request
        vault.createWithdrawalRequest(0.5 ether);
        assertEq(vault.withdrawalRequestCount(alice), 1);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.shares, 0.5 ether);

        // Creates second withdrawal request
        vault.createWithdrawalRequest(0.2 ether);
        assertEq(vault.withdrawalRequestCount(alice), 2);
        request_ = vault.withdrawalRequests(alice, 1);
        assertEq(request_.shares, 0.2 ether);

        // Creates third withdrawal request
        vault.createWithdrawalRequest(0.3 ether);
        assertEq(vault.withdrawalRequestCount(alice), 3);
        request_ = vault.withdrawalRequests(alice, 2);
        assertEq(request_.shares, 0.3 ether);

        // Cannot create fouth (out of balance).
        // Count remains the same, next index in array unaccessible.
        vm.expectRevert("LRDT:INSUFFICIENT_BALANCE");
        vault.createWithdrawalRequest(0.1 ether);
        assertEq(vault.withdrawalRequestCount(alice), 3);
        vm.expectRevert(stdError.indexOOBError);
        vault.withdrawalRequests(alice, 3);

        // Can cancel third.
        // Count remains the same, previous index accessible.
        vault.cancelWithdrawalRequest(2);
        assertEq(vault.withdrawalRequestCount(alice), 3);
        request_ = vault.withdrawalRequests(alice, 2);
        assertEq(request_.shares, 0);
    }

    function testCancelWithdrawalRequest(uint256 assets_) public {
        assets_ = bound(assets_, 1, type(uint96).max);

        _setUpDepositor(alice, assets_);

        uint256 shares_ = vault.balanceOf(alice);
        vault.createWithdrawalRequest(shares_);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        assertGt(request_.shares, 0);

        vm.warp(block.timestamp + 2 weeks);
        vault.cancelWithdrawalRequest(0);
        request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.unlockedAt, 0);
        assertEq(request_.shares, 0);
        assertEq(request_.assets, 0);
    }

    function testCancelWithdrawalRequestAfterRewards(uint256 assets_) public {
        assets_ = bound(assets_, 20, type(uint96).max);

        _setUpDepositor(bob, assets_);
        _setUpDepositor(alice, assets_);

        uint256 shares_ = vault.balanceOf(alice);
        vault.createWithdrawalRequest(shares_);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        assertGt(request_.shares, 0);

        uint256 rewards_ = assets_ / 10;
        _addAndVestRewards(rewards_);

        uint256 expectedRefund_ = vault.convertToShares(assets_);
        uint256 expectedAssets_ = vault.convertToAssets(expectedRefund_);
        uint256 expectedBurn_ = request_.shares - expectedRefund_;
        uint256 expectedBurnAssets_ = vault.convertToAssets(expectedBurn_);
        uint256 previousSupply_ = vault.totalSupply();

        vault.cancelWithdrawalRequest(0);

        request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.unlockedAt, 0);
        assertEq(request_.shares, 0);
        assertEq(request_.assets, 0);
        assertEq(vault.balanceOf(alice), expectedRefund_);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(address(vault)), asset.totalSupply());
        assertEq(expectedBurn_, previousSupply_ - vault.totalSupply());
        assertGt(expectedBurn_, 0);

        // The maximum difference between input assets and remaining expected assets would be 2 as this indicates two
        // floor operations when converting between shares and assets.
        assertLe(assets_ - expectedAssets_, 2);

        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 weeks);

        // The maximum difference between the final balanceOfAssets and the pre-burn expected assets is 1. When
        // performing the burn we reduce free assets, altering the totalAssets, which is used as both a numerator and
        // denominator in the conversion functions. This change of num/den can result in an additional 1 asset.
        assertLe(asset.totalSupply() - vault.totalAssets(), 1);

        // When cancelling a withdrawal request the rewards earned by the vault are shared with all stakers, including
        // the one performing the cancellation. In this instance Alice receives assets proportional to their percentage
        // of total supply. Bob then receives all of the rewards accrued, less the assets awarded to Alice during burn.
        assertLe(vault.balanceOfAssets(alice) + vault.balanceOf(bob), vault.totalAssets());
        uint256 aliceBurnAssets_ = (expectedBurnAssets_ * vault.balanceOf(alice)) / vault.totalSupply();
        assertLe(vault.balanceOfAssets(alice) - (expectedAssets_ + aliceBurnAssets_), 2);
        // rewards_ performs one floor operation, aliceBurnAssets_ performs three, balanceOfAssets performs one,
        // resulting in maximum remainder within test case of three.
        assertLe((assets_ + rewards_ - aliceBurnAssets_) - vault.balanceOfAssets(bob), 3);
    }

    function testTransferActiveWithdrawalRequest() public {
        _setUpDepositor(alice, 1 ether);
        vault.approve(alice, 1 ether);
        uint256 shares_ = vault.balanceOf(alice);

        // Cannot transfer shares within withdrawal request.
        vault.createWithdrawalRequest(shares_ / 2);
        vm.expectRevert(stdError.arithmeticError);
        vault.transfer(bob, shares_);
        vm.expectRevert(stdError.arithmeticError);
        vault.transferFrom(alice, bob, shares_);

        // Can transfer shares outside of withdrawal request.
        vault.transfer(bob, shares_ / 4);
        vault.transferFrom(alice, bob, shares_ / 4);
        assertEq(vault.balanceOf(bob), shares_ / 2);

        // Can transfer remaining shares after cancel withdrawal request.
        vault.cancelWithdrawalRequest(0);
        vault.transfer(bob, shares_ / 4);
        vault.transferFrom(alice, bob, shares_ / 4);
        assertEq(vault.balanceOf(bob), shares_);
    }

    function testCannotWithdrawLockedWithdrawalRequest(uint256 assets_) public {
        assets_ = bound(assets_, 2, type(uint96).max);

        _setUpDepositor(alice, assets_);
        uint256 shares_ = vault.balanceOf(alice);

        vault.createWithdrawalRequest(shares_ / 2);

        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.unlockedAt, block.timestamp + 26 weeks);
        assertEq(request_.shares, shares_ / 2);
        assertEq(request_.assets, assets_ / 2);

        vm.expectRevert(stdError.arithmeticError);
        vault.withdraw(assets_, alice, alice);
    }

    function testCannotRedeemLockedWithdrawalRequest(uint256 assets_) public {
        assets_ = bound(assets_, 2, type(uint96).max);

        _setUpDepositor(alice, assets_);
        uint256 shares_ = vault.balanceOf(alice);

        vault.createWithdrawalRequest(shares_ / 2);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.unlockedAt, block.timestamp + 26 weeks);
        assertEq(request_.shares, shares_ / 2);
        assertEq(request_.assets, assets_ / 2);

        vm.expectRevert(stdError.arithmeticError);
        vault.redeem(shares_, alice, alice);
    }

    function testExecuteWithdrawalRequest(uint256 assets_) public {
        assets_ = bound(assets_, 2, type(uint96).max);

        _setUpDepositor(alice, assets_);
        uint256 shares_ = vault.balanceOf(alice);
        uint256 halfOfShares_ = shares_ / 2;
        uint256 remainderShares_ = shares_ - halfOfShares_;

        // Test withdrawal request properties after creation
        vault.createWithdrawalRequest(halfOfShares_);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        vm.warp(block.timestamp + 26 weeks);
        assertEq(request_.unlockedAt, block.timestamp);
        assertEq(request_.shares, halfOfShares_);
        assertEq(request_.assets, assets_ / 2);

        // Test withdrawal request properties after execution
        vault.executeWithdrawalRequest(0);
        request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.unlockedAt, 0);
        assertEq(request_.shares, 0);
        assertEq(request_.assets, 0);
        assertEq(asset.balanceOf(alice), assets_ / 2);
        assertEq(vault.balanceOf(alice), remainderShares_);
    }

    function testExecuteWithdrawalRequestWithFeeVaryingAssets(uint256 assets_) public {
        assets_ = bound(assets_, 100, type(uint96).max);

        _setUpDepositor(alice, assets_);
        uint256 shares_ = vault.balanceOf(alice);

        vault.createWithdrawalRequest(shares_);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        vm.warp(block.timestamp + 13 weeks);
        assertEq(request_.unlockedAt, block.timestamp + 13 weeks);
        assertEq(request_.shares, shares_);
        assertEq(request_.assets, assets_);

        vault.executeWithdrawalRequest(0);

        uint256 expectedAssets_ = (assets_ * (1000 - 75)) / 1000;
        assertEq(asset.balanceOf(alice), expectedAssets_);
        assertEq(vault.balanceOf(alice), 0);
    }

    function testExecuteWithdrawalRequestWithFeeVaryingRemainingTime(uint256 remainingTime_) public {
        uint256 assets_ = 1 ether;
        remainingTime_ = bound(remainingTime_, 0, 26 weeks);

        _setUpDepositor(alice, assets_);
        uint256 shares_ = vault.balanceOf(alice);

        vault.createWithdrawalRequest(shares_);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        vm.warp(block.timestamp + 26 weeks - remainingTime_);
        assertEq(request_.unlockedAt, block.timestamp + remainingTime_);

        vault.executeWithdrawalRequest(0);

        uint256 precision_ = vault.precision();
        uint256 feePercentage_ = (instantWithdrawalFee * remainingTime_ * precision_) / request_.lockTime;
        uint256 expectedAssets_ = (assets_ * (100 * precision_ - feePercentage_)) / (100 * precision_);
        assertEq(asset.balanceOf(alice), expectedAssets_);
        assertEq(vault.balanceOf(alice), 0);
    }

    function testExecuteWithdrawalRequestWithFeeFixedCases() public {
        vault.setWithdrawalFeeExemption(bob, true);

        uint64[27] memory expectedAssets_ = [
            850000000000000000,
            855769230769230769,
            861538461538461538,
            867307692307692307,
            873076923076923076,
            878846153846153846,
            884615384615384615,
            890384615384615384,
            896153846153846153,
            901923076923076923,
            907692307692307692,
            913461538461538461,
            919230769230769230,
            925000000000000000,
            930769230769230769,
            936538461538461538,
            942307692307692307,
            948076923076923076,
            953846153846153846,
            959615384615384615,
            965384615384615384,
            971153846153846153,
            976923076923076923,
            982692307692307692,
            988461538461538461,
            994230769230769230,
            1000000000000000000
        ];

        uint256 weeks_ = 604_800;

        for (uint256 i_; i_ < expectedAssets_.length; i_++) {
            vm.startPrank(bob);
            asset.approve(address(vault), type(uint256).max);
            asset.mint(bob, 1 ether);
            vault.deposit(1 ether, bob);
            vm.stopPrank();

            vm.startPrank(alice);
            asset.approve(address(vault), type(uint256).max);
            asset.mint(alice, 1 ether);
            vault.deposit(1 ether, alice);

            vault.createWithdrawalRequest(vault.balanceOf(alice));
            assertEq(vault.balanceOfAssets(alice), 0);
            assertEq(vault.balanceOf(alice), 0);

            ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, i_);
            vm.warp(block.timestamp + i_ * weeks_);
            assertEq(request_.unlockedAt, block.timestamp + (26 - i_) * weeks_);

            vault.executeWithdrawalRequest(i_);

            // Update vesting schedule to catch redistributed fees within next cycle.
            vault.updateVestingSchedule();
            vm.warp(block.timestamp + 2 weeks);

            assertEq(vault.balanceOfAssets(alice), 0);
            assertEq(vault.balanceOf(alice), 0);
            assertEq(asset.balanceOf(alice), expectedAssets_[i_]);

            // Cleanup
            asset.transfer(address(0), asset.balanceOf(alice));
            vm.stopPrank();

            vm.startPrank(bob);
            vault.redeem(vault.balanceOf(bob), bob, bob);
            vm.stopPrank();
            assertLe(asset.balanceOf(address(vault)), 1);
        }
    }

    function testExecuteWithdrawalRequestWithRewards() public {
        asset.mint(alice, 1 ether);
        asset.mint(bob, 3 ether);

        vm.startPrank(bob);
        asset.approve(address(vault), 3 ether);
        vault.deposit(3 ether, bob);
        vm.stopPrank();

        vm.startPrank(alice);
        asset.approve(address(vault), 1 ether);
        vault.deposit(1 ether, alice);
        uint256 shares_ = vault.balanceOf(alice);
        assertEq(asset.balanceOf(alice), 0);

        // Add rewards prior to first withdrawal request.
        asset.mint(address(vault), 0.1 ether);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 weeks);

        // Create and check first withdrawal request.
        vault.createWithdrawalRequest(shares_);
        ILockedRevenueDistributionToken.WithdrawalRequest memory request_ = vault.withdrawalRequests(alice, 0);
        assertEq(request_.unlockedAt, block.timestamp + 26 weeks);
        assertEq(request_.shares, shares_);
        assertEq(request_.assets, 1.025 ether - 1);

        // Add rewards after withdrawal request, but prior to execution.
        asset.mint(address(vault), 0.3 ether);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 weeks);

        // Check that withdrawn assets matches request.
        vm.warp(block.timestamp + 26 weeks);
        vault.executeWithdrawalRequest(0);
        request_ = vault.withdrawalRequests(alice, 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(asset.balanceOf(alice), 1.025 ether - 1);

        // Update vesting schedule to catch redistributed fees within next cycle.
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 weeks);

        // Check that difference between request and underlying is shared. e.g. Bob would get the full 0.3 ether from
        // second distribution.
        assertEq(vault.balanceOfAssets(bob), 3 ether + 0.3 ether + 0.075 ether);
        assertGe(asset.balanceOf(address(vault)), vault.balanceOfAssets(bob));
    }

    function testUserWithdrawalRequests() public {
        asset.mint(alice, 3 ether);

        vm.startPrank(alice);
        asset.approve(address(vault), 3 ether);
        vault.deposit(3 ether, alice);

        vault.createWithdrawalRequest(1 ether);
        vault.createWithdrawalRequest(1 ether);
        vault.createWithdrawalRequest(1 ether);

        vm.stopPrank();

        ILockedRevenueDistributionToken.WithdrawalRequest[] memory request_ = vault.withdrawalRequests(alice);

        assertEq(request_.length, 3);

        assertEq(request_[0].shares, 1 ether);
        assertEq(request_[0].assets, vault.convertToAssets(1 ether));
        assertEq(request_[0].unlockedAt, block.timestamp + vault.lockTime());

        assertEq(request_[1].shares, 1 ether);
        assertEq(request_[1].assets, vault.convertToAssets(1 ether));
        assertEq(request_[1].unlockedAt, block.timestamp + vault.lockTime());

        assertEq(request_[2].shares, 1 ether);
        assertEq(request_[2].assets, vault.convertToAssets(1 ether));
        assertEq(request_[2].unlockedAt, block.timestamp + vault.lockTime());
    }

    function testUserWithdrawalRequestsCancelled() public {
        asset.mint(alice, 3 ether);

        vm.startPrank(alice);
        asset.approve(address(vault), 3 ether);
        vault.deposit(3 ether, alice);

        vault.createWithdrawalRequest(1 ether);
        vault.createWithdrawalRequest(1 ether);
        vault.createWithdrawalRequest(1 ether);

        vault.cancelWithdrawalRequest(0);
        vault.cancelWithdrawalRequest(1);
        vault.cancelWithdrawalRequest(2);

        vm.stopPrank();

        ILockedRevenueDistributionToken.WithdrawalRequest[] memory request_ = vault.withdrawalRequests(alice);

        assertEq(request_.length, 3);

        assertEq(request_[0].shares, 0);
        assertEq(request_[0].assets, 0);
        assertEq(request_[0].unlockedAt, 0);

        assertEq(request_[1].shares, 0);
        assertEq(request_[1].assets, 0);
        assertEq(request_[1].unlockedAt, 0);

        assertEq(request_[2].shares, 0);
        assertEq(request_[2].assets, 0);
        assertEq(request_[2].unlockedAt, 0);
    }

    function testUserWithdrawalRequestsExecuted() public {
        asset.mint(alice, 3 ether);

        vm.startPrank(alice);
        asset.approve(address(vault), 3 ether);
        vault.deposit(3 ether, alice);

        vault.createWithdrawalRequest(1 ether);
        vault.createWithdrawalRequest(1 ether);
        vault.createWithdrawalRequest(1 ether);

        vm.warp(block.timestamp + 26 weeks);

        vault.executeWithdrawalRequest(0);
        vault.executeWithdrawalRequest(1);
        vault.executeWithdrawalRequest(2);

        vm.stopPrank();

        ILockedRevenueDistributionToken.WithdrawalRequest[] memory request_ = vault.withdrawalRequests(alice);

        assertEq(request_.length, 3);

        assertEq(request_[0].shares, 0);
        assertEq(request_[0].assets, 0);
        assertEq(request_[0].unlockedAt, 0);

        assertEq(request_[1].shares, 0);
        assertEq(request_[1].assets, 0);
        assertEq(request_[1].unlockedAt, 0);

        assertEq(request_[2].shares, 0);
        assertEq(request_[2].assets, 0);
        assertEq(request_[2].unlockedAt, 0);
    }

    function testFrontRunWithdraw() public {
        address eve = address(0x0E5E);

        // first Alice deposit
        _setUpDepositor(alice, 1 ether);
        // We add some profit
        asset.mint(address(vault), 1 ether);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 days);
        // Alice starts a withdrawal request
        vault.createWithdrawalRequest(1 ether);
        // we increase time to reach the end of the lock
        vm.warp(block.timestamp + 26 weeks);
        // Bob deposit
        _setUpDepositor(bob, 1 ether);
        vm.stopPrank();
        // Alice execute the withdraw
        vm.startPrank(alice);
        vault.executeWithdrawalRequest(0);

        // Eve deposit
        vm.stopPrank();
        _setUpDepositor(eve, 1 ether);
        vm.stopPrank();

        assertApproxEqRel(vault.balanceOf(eve), vault.balanceOf(bob), 10e6);
    }
}
