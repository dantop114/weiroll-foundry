// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";

contract SimpleToken is ERC20 {
    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function name() public pure override returns (string memory) {
        return "SimpleToken";
    }

    function symbol() public pure override returns (string memory) {
        return "SIMPLE";
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {}
}
