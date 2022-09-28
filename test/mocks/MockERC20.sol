// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import "erc20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_, 18) {}

    function mint(address to_, uint256 value_) public virtual {
        _mint(to_, value_);
    }

    function burn(address from, uint256 value_) public virtual {
        _burn(from, value_);
    }
}
