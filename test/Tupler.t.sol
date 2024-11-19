// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {WeirollPlanner} from "./utils/WeirollPlanner.sol";

import {VM} from "../src/VM.sol";

import {LibTupler} from "../src/test/Tupler.sol";
import {TestableVM} from "../src/test/TestableVM.sol";
import {MultiReturn} from "../src/test/MultiReturn.sol";

contract TuplerTest is Test {
    TestableVM vm__;

    LibTupler libTupler__;
    MultiReturn multiReturn__;

    function setUp() public {
        vm__ = new TestableVM();
        libTupler__ = new LibTupler();
        multiReturn__ = new MultiReturn();
    }

    /// @dev Should perform a tuple return that's sliced before being fed to another function (first var)
    function test_tupler1() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            MultiReturn.intTuple.selector, 0x41, bytes6(0xff0000000000), bytes1(0x00), address(multiReturn__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            LibTupler.extractElement.selector, 0x01, bytes6(0x8001ff000000), bytes1(0x00), address(libTupler__)
        );

        bytes32 command3 = WeirollPlanner.buildCommand(
            MultiReturn.tupleConsumer.selector, 0x01, bytes6(0x00ffffffffff), bytes1(0xff), address(multiReturn__)
        );

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = command1;
        commands[1] = command2;
        commands[2] = command3;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(0);
        state[1] = abi.encode(0);

        vm.expectEmit();
        emit MultiReturn.Calculated(0xbad);

        vm__.execute(commands, state);
    }

    /// @dev Should perform a tuple return that's sliced before being fed to another function (second var)
    function test_tupler2() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            MultiReturn.intTuple.selector, 0x41, bytes6(0xff0000000000), bytes1(0x00), address(multiReturn__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            LibTupler.extractElement.selector, 0x01, bytes6(0x8001ff000000), bytes1(0x00), address(libTupler__)
        );

        bytes32 command3 = WeirollPlanner.buildCommand(
            MultiReturn.tupleConsumer.selector, 0x01, bytes6(0x00ffffffffff), bytes1(0xff), address(multiReturn__)
        );

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = command1;
        commands[1] = command2;
        commands[2] = command3;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(0);
        state[1] = abi.encode(1);

        vm.expectEmit();
        emit MultiReturn.Calculated(0xdeed);

        vm__.execute(commands, state);
    }
}
