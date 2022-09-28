// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./LockedRevenueDistributionTokenBaseTest.t.sol";

contract InstantWithdrawalTest is LockedRevenueDistributionTokenBaseTest {
    function testSetInstantWithdrawalFee(uint256 percentage_) public {
        percentage_ = bound(percentage_, 0, 99);
        vault.setInstantWithdrawalFee(percentage_);
        assertEq(vault.instantWithdrawalFee(), percentage_);
        assertEq(vault.previewRedeem(100), (100 * (100 - percentage_)) / 100);
        assertEq(vault.previewWithdraw(100), (100 * 100) / (100 - percentage_));
    }

    function testCannotSetInstantWithdrawalFeeAboveBound() public {
        vm.expectRevert("LRDT:INVALID_FEE");
        vault.setInstantWithdrawalFee(100);
    }

    function testSetAndUnsetWithdrawalFeeExemption() public {
        assertFalse(vault.withdrawalFeeExemptions(alice));

        vault.setWithdrawalFeeExemption(alice, true);
        assertTrue(vault.withdrawalFeeExemptions(alice));

        vault.setWithdrawalFeeExemption(alice, false);
        assertFalse(vault.withdrawalFeeExemptions(alice));
    }

    function testCannotSetWithdrawalFeeExemptionZeroAddress() public {
        assertFalse(vault.withdrawalFeeExemptions(address(0)));
        vm.expectRevert("LRDT:ZERO_ACCOUNT");
        vault.setWithdrawalFeeExemption(address(0), true);
        assertFalse(vault.withdrawalFeeExemptions(address(0)));
    }

    function testFeeExemptRedemption(uint256 assets_) public {
        assets_ = bound(assets_, 1, type(uint96).max);
        vault.setWithdrawalFeeExemption(alice, true);

        _setUpDepositor(alice, assets_);

        assertEq(asset.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), assets_); // First deposit is 1:1

        vault.redeem(vault.balanceOf(alice), alice, alice);
        assertEq(asset.balanceOf(alice), assets_);
        assertEq(vault.balanceOf(alice), 0);
    }

    function testInstantWithdrawalFeeRedeem(uint256 assets_) public {
        // A lower bound of 2 is required to leave some asset amount available after rounding. After taking a 10% of 1,
        // this would leave 0.9 asset to be returned to the user, which is rounded down to 0.
        assets_ = bound(assets_, 2, type(uint96).max);

        _setUpDepositor(alice, assets_);

        assertEq(asset.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), assets_);

        uint256 shares_ = vault.balanceOf(alice);
        uint256 expectedAssets_ = (assets_ * (100 - instantWithdrawalFee)) / 100;
        uint256 expectedFee_ = assets_ - expectedAssets_;
        assertEq(vault.previewRedeem(shares_), expectedAssets_);
        (uint256 previewAssets_, uint256 previewFee_) = vault.previewRedeem(shares_, alice);
        assertEq(previewAssets_, expectedAssets_);
        assertEq(previewFee_, expectedFee_);

        vault.redeem(shares_, alice, alice);
        assertEq(asset.balanceOf(alice), expectedAssets_);
        assertEq(vault.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testInstantWithdrawalFeeWithdraw(uint256 assets_) public {
        assets_ = bound(assets_, 2, type(uint96).max);

        _setUpDepositor(alice, assets_);

        assertEq(asset.balanceOf(alice), 0);
        assertEq(vault.balanceOf(alice), assets_);

        // A withdrawal is the reverse action to a redeem and operates on the number of shares required to redeem a
        // certain amount of assets. The rounding can become confusing due to the instant withdrawal fee.
        //
        // The amount of assets returned to the user must always be rounded down, hence we use minExpectedAssets_
        // below when asserting equality of the withdrawal amount.
        //
        // The following is true:
        //   1. When withdrawing the minimum, the shares taken should be less than or equal to the user's balance.
        //   2. When withdrawing the maximum, the shares taken should be more than or equal to the user's balance.
        //
        // Because of precision the true amount of assets to be returned to a user will always need to be rounded, so
        // when rounding down this can leave the user with one remaining share that is unable to be redeemed for
        // remaining assets.
        uint256 shares_ = vault.balanceOf(alice);
        uint256 minExpectedAssets_ = _applyInstantWithdrawalFee(assets_);
        uint256 maxExpectedAssets_ = _divRoundUp((assets_ * (100 - instantWithdrawalFee)), 100);
        uint256 expectedShares_ = (shares_ * 100) / (100 - instantWithdrawalFee);
        assertEq(vault.previewWithdraw(assets_), expectedShares_);
        assertLe(vault.previewWithdraw(minExpectedAssets_), shares_);
        assertGe(vault.previewWithdraw(maxExpectedAssets_), shares_);
        (uint256 previewShares_, uint256 previewFee_) = vault.previewWithdraw(assets_, alice);
        assertEq(previewShares_, expectedShares_);
        (previewShares_, previewFee_) = vault.previewWithdraw(minExpectedAssets_, alice);
        assertLe(previewShares_, shares_);
        assertLe(previewFee_, assets_ - minExpectedAssets_);
        (previewShares_, previewFee_) = vault.previewWithdraw(maxExpectedAssets_, alice);
        assertGe(previewShares_, shares_);
        assertGe(previewFee_, assets_ - maxExpectedAssets_);

        vault.withdraw(minExpectedAssets_, alice, alice);
        assertEq(asset.balanceOf(alice), minExpectedAssets_);
        // The maximum possible remaining shares would be 2, because this would indicate two `floor` operations, one
        // rounding down the minExpectedAssets and another rounding down the result of converting assets to shares.
        //
        // This is only an issue in calculation for withdraw, and not for redeem. Take the example of withdrawing 34
        // assets. This results in floor(28.9) => 28 shares at a 15% fee and 1:1 rate. 28 shares would withdraw
        // floor(32.9) => 32 assets from a total of 34, leaving 2.
        assertLe(vault.balanceOf(alice), 2);

        // When attempting to withdraw the maximum expected assests, rounded up from the amount of shares, this will
        // always fail. The withdraw function will ensure that the amount of shares is also rounded up resulting in one
        // greater share than the available balance.
        vm.expectRevert(stdError.arithmeticError);
        vault.withdraw(maxExpectedAssets_, alice, alice);
        vm.stopPrank();
    }

    function testInstantWithdrawalFeeSharing() public {
        _setUpDepositor(alice, 1 ether);
        _setUpDepositor(bob, 2 ether);

        vault.redeem(vault.balanceOf(bob), bob, bob);
        uint256 bobFee_ = _instantWithdrawalFee(2 ether); // == 0.3 ether
        assertEq(asset.balanceOf(bob), 2 ether - bobFee_);
        vm.stopPrank();

        assertEq(vault.balanceOfAssets(alice), 1 ether + bobFee_);
        assertEq(vault.previewRedeem(vault.balanceOf(alice)), _applyInstantWithdrawalFee(1 ether + bobFee_));
    }
}
