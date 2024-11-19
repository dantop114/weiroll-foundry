// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.28;

import {Events} from "./Events.sol";

contract Fallback is Events {
    receive() external payable {
        if (msg.value > 0) emit LogUint(msg.value);
    }

    fallback() external payable {
        if (msg.value > 0) emit LogUint(msg.value);
        if (msg.data.length > 0) emit LogBytes(msg.data);
    }
}
