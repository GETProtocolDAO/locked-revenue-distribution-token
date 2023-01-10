// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./LockedRevenueDistributionTokenBaseTest.t.sol";

contract InitialDepositTest is LockedRevenueDistributionTokenBaseTest {
    uint256 constant initialSeed = 1 ether;

    function testCannotDeployWithoutApproval() public {
        vm.expectRevert("LRDT:C:TRANSFER_FROM");
        _deploy();
    }

    function testCannotDeployInsufficientBalance() public {
        asset.approve(_getAddress(), initialSeed);
        vm.expectRevert("LRDT:C:TRANSFER_FROM");
        _deploy();
    }

    function testDeployWithApproval() public {
        address predictedAddress_ = _getAddress();

        asset.mint(address(this), initialSeed);
        asset.approve(predictedAddress_, initialSeed);

        LockedRevenueDistributionToken vault = _deploy();
        assertEq(address(vault), predictedAddress_);
    }

    function testDeployHasBurnedShares() public {
        asset.mint(address(this), initialSeed);
        asset.approve(_getAddress(), initialSeed);

        LockedRevenueDistributionToken vault = _deploy();
        assertEq(vault.balanceOf(address(0)), initialSeed);
        assertEq(vault.balanceOfAssets(address(0)), initialSeed);
        assertEq(asset.balanceOf(address(vault)), initialSeed);
        assertEq(vault.freeAssets(), initialSeed);
        assertEq(vault.totalAssets(), initialSeed);
    }

    function testDonationAttack() public {
        asset.mint(address(this), initialSeed);
        asset.approve(_getAddress(), initialSeed);

        // The current `vault` in use has been initialized with an initialSeed value of 0, meaning no shares have been
        // burned as part of the constructor. These burned shares are necessary to prevent donation attacks.
        //
        // We first demonstrate these attacks on the contract using the unprotected vault with dust remaining.
        // Alice deposts 1 ether and withdraws all but a dust amount.
        _setUpDepositor(alice, 1 ether);
        uint256 allButDust = 1 ether - 1;
        vault.createWithdrawalRequest(allButDust);
        vm.warp(block.timestamp + 26 weeks);
        vault.executeWithdrawalRequest(0);
        vm.stopPrank();
        assertEq(vault.previewDeposit(1 ether), 1 ether);

        // Another user, Bob, can perform a donation to the contract introducing a large skew in precision between the
        // number of shares remaining (1) and the assets donated (14 ether). This 14 ether deposit vastly increases the
        // rate of shares:assets making further deposits unfeasible.
        asset.mint(bob, 14 ether + 1);
        // Bob performs the donation. With a 1 day wait, it will require 14 times the capital of the other user to
        // issue 0 shares. This is because the vesting schedule follows a linear issuance mechanism over the course of
        // 14 days.
        vm.startPrank(bob);
        asset.transfer(address(vault), 14 ether + 1);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 1 days);
        vm.stopPrank();
        assertEq(vault.previewDeposit(1 ether), 0);

        // To demonstrate the protection we now demonstrate the deployment of a new vault that requires burning of 1
        // ether worth of shares within the constructor.
        asset.mint(address(this), initialSeed);
        asset.approve(_getAddress(), initialSeed);
        vault = _deploy();

        // Alice is then setup within the new vault and performs the same withdrawal.
        _setUpDepositor(alice, 1 ether);
        vault.createWithdrawalRequest(allButDust);
        vm.warp(block.timestamp + 26 weeks);
        vault.executeWithdrawalRequest(0);
        vm.stopPrank();
        assertEq(vault.previewDeposit(1 ether), 1 ether);

        // However now Bob is unable to mark down further deposits to 0 due to the 1 ether worth of burned shares that
        // still remains on the zero address.
        assertEq(vault.balanceOf(address(0)), initialSeed);
        assertEq(asset.balanceOf(address(vault)), initialSeed + 1);
        asset.mint(bob, 14 ether + 1);
        vm.startPrank(bob);
        asset.transfer(address(vault), 14 ether + 1);
        vault.updateVestingSchedule();
        vm.warp(block.timestamp + 1 days);
        vm.stopPrank();
        assertEq(vault.previewDeposit(1 ether), 0.5 ether);
    }

    function _getBytecode() internal view returns (bytes memory) {
        bytes memory bytecode = type(LockedRevenueDistributionToken).creationCode;

        return abi.encodePacked(
            bytecode,
            abi.encode(
                "xASSET",
                "xASSET",
                address(this),
                address(asset),
                type(uint96).max,
                instantWithdrawalFee,
                26 weeks,
                initialSeed
            )
        );
    }

    function _getAddress() internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32("salt"), keccak256(_getBytecode())))
                )
            )
        );
    }

    function _deploy() internal returns (LockedRevenueDistributionToken) {
        return new LockedRevenueDistributionToken{salt: bytes32("salt")}(
            "xASSET",
            "xASSET",
            address(this),
            address(asset),
            type(uint96).max,
            instantWithdrawalFee,
            26 weeks,
            initialSeed
        );
    }
}
