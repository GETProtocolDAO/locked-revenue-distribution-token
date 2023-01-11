// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./LockedRevenueDistributionTokenBaseTest.t.sol";

contract ERC5143Test is LockedRevenueDistributionTokenBaseTest {
    function testCannotDepositOutsideSlippage() public {
        _mintAndApprove(1 ether);
        vm.expectRevert("LRDT:D:SLIPPAGE_PROTECTION");
        vault.deposit(1 ether, alice, 2 ether);
    }

    function testDepositWithinSlippage() public {
        _mintAndApprove(1 ether);
        vault.deposit(1 ether, alice, 0.5 ether);
    }

    function testCannotMintOutsideSlippage() public {
        _mintAndApprove(1 ether);
        vm.expectRevert("LRDT:M:SLIPPAGE_PROTECTION");
        vault.mint(1 ether, alice, 0.5 ether);
    }

    function testMintWithinSlippage() public {
        _mintAndApprove(1 ether);
        vault.mint(1 ether, alice, 2 ether);
    }

    function testRedeemOutsideSlippage() public {
        _setUpDepositor(alice, 1 ether);
        vm.expectRevert("LRDT:R:SLIPPAGE_PROTECTION");
        vault.redeem(1 ether, alice, alice, 2 ether);
    }

    function testRedeemWithinSlippage() public {
        _setUpDepositor(alice, 1 ether);
        vault.redeem(1 ether, alice, alice, 0.5 ether);
    }

    function testWithdrawOutsideSlippage() public {
        _setUpDepositor(alice, 1 ether);
        vm.expectRevert("LRDT:W:SLIPPAGE_PROTECTION");
        vault.withdraw(0.85 ether, alice, alice, 0.5 ether); // Account for instant withdrawal fee.
    }

    function testWithdrawWithinSlippage() public {
        _setUpDepositor(alice, 1 ether);
        vault.withdraw(0.85 ether, alice, alice, 2 ether); // Account for instant withdrawal fee.
    }
}
