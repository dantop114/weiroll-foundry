// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {WeirollPlanner} from "./utils/WeirollPlanner.sol";

import {VM} from "../src/VM.sol";
import {Math} from "../src/test/Math.sol";
import {Events} from "../src/test/Events.sol";
import {Sender} from "../src/test/Sender.sol";
import {Revert} from "../src/test/Revert.sol";
import {Strings} from "../src/test/Strings.sol";
import {Payable} from "../src/test/Payable.sol";
import {Fallback} from "../src/test/Fallback.sol";
import {StateTest} from "../src/test/StateTest.sol";
import {TestableVM} from "../src/test/TestableVM.sol";
import {SimpleToken} from "../src/test/SimpleToken.sol";

contract VMTest is Test {
    Math math__;
    Events events__;
    Sender sender__;
    Revert revert__;
    Strings strings__;
    Payable payable__;
    SimpleToken token__;
    Fallback fallback__;
    StateTest stateTest__;

    TestableVM vm__;

    function setUp() public {
        vm__ = new TestableVM();

        math__ = new Math();
        events__ = new Events();
        sender__ = new Sender();
        revert__ = new Revert();
        strings__ = new Strings();
        payable__ = new Payable();
        fallback__ = new Fallback();
        stateTest__ = new StateTest();
        token__ = new SimpleToken(100 ether);
    }

    /// @dev Should return msg.sender
    function test_shouldReturnMsgSender() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Sender.sender.selector, 0x00, bytes6(0xff0000000000), bytes1(0x01), address(sender__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            Events.logAddress.selector, 0x01, bytes6(0x01ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = command1;
        commands[1] = command2;

        bytes[] memory state = new bytes[](2);

        vm.expectEmit();
        emit Events.LogAddress(address(this));

        vm__.execute(commands, state);
    }

    /// @dev Should execute a simple addition program
    function test_shouldExecuteAddition() public {
        bytes32 command1 =
            WeirollPlanner.buildCommand(Math.add.selector, 0x01, bytes6(0x0001ff000000), bytes1(0x02), address(math__));

        bytes32 command2 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x02ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = command1;
        commands[1] = command2;

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(1);
        state[1] = abi.encode(2);

        vm.expectEmit();
        emit Events.LogUint(3);

        vm__.execute(commands, state);
    }

    /// @dev Should execute a string length program
    function test_shouldExecuteStringLength() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Strings.strlen.selector, 0x01, bytes6(0x80ff00000000), bytes1(0x01), address(strings__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x01ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = command1;
        commands[1] = command2;

        bytes memory inputString = WeirollPlanner.stringToBytes("Hello, world!");

        bytes[] memory state = new bytes[](2);
        state[0] = inputString;

        vm.expectEmit();
        emit Events.LogUint(13);

        vm__.execute(commands, state);
    }

    /// @dev Should concatenate two strings
    function test_shouldConcatenateStrings() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Strings.strcat.selector, 0x01, bytes6(0x8081ff000000), bytes1(0x82), address(strings__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            Events.logString.selector, 0x01, bytes6(0x82ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = command1;
        commands[1] = command2;

        bytes memory inputString1 = WeirollPlanner.stringToBytes("Hello, ");
        bytes memory inputString2 = WeirollPlanner.stringToBytes("world!");

        bytes[] memory state = new bytes[](3);
        state[0] = inputString1;
        state[1] = inputString2;

        vm.expectEmit();
        emit Events.LogString("Hello, world!");

        vm__.execute(commands, state);
    }

    /// @dev Should sum an array of uints
    function test_shouldSumArrayOfUints() public {
        bytes32 command1 =
            WeirollPlanner.buildCommand(Math.sum.selector, 0x01, bytes6(0x80ff00000000), bytes1(0x01), address(math__));

        bytes32 command2 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x01ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = command1;
        commands[1] = command2;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(5), uint256(1), uint256(2), uint256(3), uint256(4), uint256(5));

        vm.expectEmit();
        emit Events.LogUint(15);

        vm__.execute(commands, state);
    }

    /// @dev Should execute payable function
    function test_shouldExecutePayableFunction() public payable {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Payable.pay.selector, 0x03, bytes6(0x00ff00000000), bytes1(0xff), address(payable__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            Payable.balance.selector, 0x01, bytes6(0xff0000000000), bytes1(0x01), address(payable__)
        );

        bytes32 command3 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x01ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = command1;
        commands[1] = command2;
        commands[2] = command3;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(1 ether);

        vm.expectEmit();
        emit Events.LogUint(1 ether);

        vm__.execute{value: 1 ether}(commands, state);
    }

    /// @dev Should pass and return raw state to functions
    function test_shouldPassAndReturnRawStateToFunctions() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            StateTest.addSlots.selector, 0x01, bytes6(0x000102feffff), bytes1(0xfe), address(stateTest__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x00ffffffffff), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](2);
        commands[0] = command1;
        commands[1] = command2;

        bytes[] memory state = new bytes[](5);
        state[0] = abi.encode(0);
        state[1] = abi.encode(3);
        state[2] = abi.encode(4);
        state[3] = abi.encode(1);
        state[4] = abi.encode(2);

        vm.expectEmit();
        emit Events.LogUint(3);

        vm__.execute(commands, state);
    }

    /// @dev Should perform a ERC20 transfer
    function test_shouldPerformERC20Transfer() public {
        token__.transfer(address(vm__), 10 ether);

        bytes32 command1 = WeirollPlanner.buildCommand(
            SimpleToken.transfer.selector, 0x01, bytes6(0x0001ff000000), bytes1(0xff), address(token__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            SimpleToken.balanceOf.selector, 0x01, bytes6(0x00ff00000000), bytes1(0x02), address(token__)
        );

        bytes32 command3 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x02ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = command1;
        commands[1] = command2;
        commands[2] = command3;

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(address(0xc0ffeeb4b3));
        state[1] = abi.encode(10 ether);

        vm.expectEmit();
        emit Events.LogUint(10 ether);

        vm__.execute(commands, state);
    }

    /// @dev Should propagate revert reasons
    function test_shouldPropagateRevertReason() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Revert.fail.selector, 0x01, bytes6(0xff0000000000), bytes1(0xff), address(revert__)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = command1;

        bytes[] memory state = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(VM.ExecutionFailed.selector, 0, address(revert__), "Hello World!"));

        vm__.execute(commands, state);
    }

    function test_shouldUseSlotAsCalldataNoValue() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            bytes4(0x00000000), 0x21, bytes6(0x000000000000), bytes1(0xff), address(fallback__)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = command1;

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(0xdeadbeef);

        vm.expectEmit();
        emit Events.LogBytes(abi.encode(0xdeadbeef));

        vm__.execute(commands, state);
    }

    function test_shouldUseSlotAsCalldataValue() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            bytes4(0x00000000), 0x23, bytes6(0x000100000000), bytes1(0xff), address(fallback__)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = command1;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(1 ether);
        state[1] = abi.encode(0xdeadbeef);

        vm.expectEmit();
        emit Events.LogUint(1 ether);
        emit Events.LogBytes(abi.encode(0xdeadbeef));

        vm__.execute{value: 1 ether}(commands, state);
    }

    function test_shouldUseSlotAsCalldataTokenTransfer() public {
        bytes32 command1 = WeirollPlanner.buildCommand(
            bytes4(0x00000000), 0x21, bytes6(0x000000000000), bytes1(0xff), address(token__)
        );

        bytes32 command2 = WeirollPlanner.buildCommand(
            SimpleToken.balanceOf.selector, 0x01, bytes6(0x01ff00000000), bytes1(0x02), address(token__)
        );

        bytes32 command3 = WeirollPlanner.buildCommand(
            Events.logUint.selector, 0x01, bytes6(0x02ff00000000), bytes1(0xff), address(events__)
        );

        bytes32[] memory commands = new bytes32[](3);
        commands[0] = command1;
        commands[1] = command2;
        commands[2] = command3;

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encodeWithSelector(SimpleToken.transfer.selector, address(0xc0ffeeb4b3), 10 ether);
        state[1] = abi.encode(address(0xc0ffeeb4b3));

        token__.transfer(address(vm__), 10 ether);

        vm.expectEmit();
        emit Events.LogUint(10 ether);

        vm__.execute(commands, state);
    }
}
