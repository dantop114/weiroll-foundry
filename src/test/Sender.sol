// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract Sender {
    function sender() public view returns (address) {
        return msg.sender;
    }
}
