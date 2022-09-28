// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "./GovernanceLockedRevenueDistributionTokenBaseTest.t.sol";

contract DelegationBySignatureTest is GovernanceLockedRevenueDistributionTokenBaseTest {
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    uint256 nonce = 0;

    function setUp() public override {
        super.setUp();
        mint(alice, mintAmount);
    }

    function _getDigest(address delegatee_, uint256 nonce_, uint256 expiry_) internal view returns (bytes32 digest_) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                vault.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee_, nonce_, expiry_))
            )
        );
    }

    function _getValidDelegationSignature(address delegatee_, uint256 nonce_, uint256 deadline_, uint256 privateKey_)
        internal
        returns (uint8 v_, bytes32 r_, bytes32 s_)
    {
        return vm.sign(privateKey_, _getDigest(delegatee_, nonce_, deadline_));
    }

    function _getInvalidDelegationSignature(address delegatee_, uint256 nonce_, uint256 deadline_, uint256 privateKey_)
        internal
        returns (uint8 v_, bytes32 r_, bytes32 s_)
    {
        // Intentionally alter the signature
        return vm.sign(privateKey_, _getDigest(delegatee_, nonce_, deadline_ - 13));
    }

    function testDelegationWithCorrectSignature() public {
        vm.roll(block.number + 1); // block.number = 2
        (uint8 v_, bytes32 r_, bytes32 s_) = _getValidDelegationSignature(alice, nonce, start + 1 days, 0x0A11CE);

        assertEq(vault.delegates(alice), address(0));

        vm.expectEmit(true, true, true, true, address(vault));
        emit DelegateChanged(alice, address(0), alice);
        vm.expectEmit(true, false, false, true, address(vault));
        emit DelegateVotesChanged(alice, 0, mintAmount);
        vault.delegateBySig(alice, nonce, block.timestamp + 1 days, v_, r_, s_);

        assertEq(vault.delegates(alice), alice);
        assertEq(vault.getVotes(alice), mintAmount);
        assertEq(vault.getPastVotes(alice, 1), 0);

        vm.roll(block.number + 1); // block.number = 3
        assertEq(vault.getPastVotes(alice, 2), mintAmount);
    }

    function testDelegationWithReusedSignature() public {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getValidDelegationSignature(alice, nonce, start + 1 days, 0x0A11CE);
        vault.delegateBySig(alice, nonce, block.timestamp + 1 days, v_, r_, s_);

        vm.expectRevert("GLRDT:DBS:INVALID_NONCE");
        vault.delegateBySig(alice, nonce, block.timestamp + 1 days, v_, r_, s_);
    }

    function testDelegationWithBadDelegatee() public {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getValidDelegationSignature(alice, nonce, start + 1 days, 0x0A11CE);

        vault.delegateBySig(bob, nonce, block.timestamp + 1 days, v_, r_, s_);

        assertFalse(vault.delegates(alice) == alice);
        assertTrue(vault.delegates(alice) == address(0));
    }

    function testDelegationWithBadNonce() public {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getValidDelegationSignature(alice, nonce, start + 1 days, 0x0A11CE);
        vm.expectRevert("GLRDT:DBS:INVALID_NONCE");
        vault.delegateBySig(alice, nonce + 1, block.timestamp + 1 days, v_, r_, s_);
    }

    function testDelegationWithExpiredPermit() public {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getValidDelegationSignature(alice, nonce, start - 1 days, 0x0A11CE);
        vm.expectRevert("GLRDT:DBS:EXPIRED");
        vault.delegateBySig(alice, nonce + 1, block.timestamp - 1 days, v_, r_, s_);
    }

    function testDelegationWithInvalidSignature() public {
        vm.roll(block.number + 1); // block.number = 2
        (uint8 v_, bytes32 r_, bytes32 s_) = _getInvalidDelegationSignature(alice, nonce, start + 1 days, 0x0A11CE);

        assertEq(vault.delegates(address(0)), address(0));
        vm.expectRevert("GLRDT:DBS:INVALID_SIGNATURE");
        // Intentionally malform the function call
        vault.delegateBySig(alice, nonce, block.timestamp + 1 days, v_, s_, r_);

        assertEq(vault.delegates(address(0)), address(0));
    }
}
