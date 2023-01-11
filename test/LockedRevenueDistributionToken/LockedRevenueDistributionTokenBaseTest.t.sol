// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "src/LockedRevenueDistributionToken.sol";
import "../mocks/MockERC20.sol";

abstract contract LockedRevenueDistributionTokenBaseTest is Test {
    address constant alice = address(0xA11CE);
    address constant bob = address(0xB0B);
    uint256 constant instantWithdrawalFee = 15;
    uint256 constant start = 10000000;
    LockedRevenueDistributionToken vault;
    MockERC20 asset;

    function setUp() public {
        asset = new MockERC20("Underlying Asset", "ASSET");
        vault = new LockedRevenueDistributionToken(
            "xASSET",
            "xASSET",
            address(this),
            address(asset),
            type(uint96).max,
            instantWithdrawalFee,
            26 weeks,
            0
        );
        vm.warp(start); // Warp to non-zero timestamp
    }

    function _setUpDepositor(address depositor_, uint256 assets_) internal {
        vm.stopPrank();

        uint256 balanceBefore_ = asset.balanceOf(depositor_);
        asset.mint(depositor_, assets_);
        vm.startPrank(depositor_);

        asset.approve(address(vault), assets_);
        vault.deposit(assets_, depositor_);
        assertEq(asset.balanceOf(depositor_), balanceBefore_);
    }

    function _mintAndApprove(uint256 assets_) internal {
        asset.mint(alice, assets_);
        vm.startPrank(alice);
        asset.approve(address(vault), assets_);
    }

    function _addAndVestRewards(uint256 assets_) internal {
        asset.mint(address(vault), assets_);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 2 weeks);
    }

    function _instantWithdrawalFee(uint256 assets_) internal pure returns (uint256 fee_) {
        fee_ = (assets_ * instantWithdrawalFee) / 100;
    }

    function _applyInstantWithdrawalFee(uint256 assets_) internal pure returns (uint256 assetsAfterFee_) {
        assetsAfterFee_ = (assets_ * (100 - instantWithdrawalFee)) / 100;
    }

    function _divRoundUp(uint256 _numerator, uint256 _divisor) internal pure returns (uint256) {
        return (_numerator / _divisor) + (_numerator % _divisor > 0 ? 1 : 0);
    }
}
