// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {VM} from "../src/VM.sol";

import {WeirollPlanner} from "./utils/WeirollPlanner.sol";

import {Math} from "../src/test/Math.sol";
import {Strings} from "../src/test/Strings.sol";
import {CommandBuilderHarness} from "../src/test/CommandBuilderHarness.sol";

contract CommandBuilderTest is Test {
    CommandBuilderHarness harness__;

    Math math__;
    Strings strings__;

    function setUp() public {
        harness__ = new CommandBuilderHarness();

        math__ = new Math();
        strings__ = new Strings();
    }

    function executeBuildInputs(
        bytes32[] memory commands,
        bytes[] memory state,
        bytes memory calldata_
    ) internal view returns (bool) {
        for (uint256 i = 0; i < commands.length; i++) {
            bytes32 command = commands[i];
            bytes4 selector = bytes4(command);

            bytes32 indices = bytes32(
                uint256(command << 40) |
                    0x000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            );

            bytes memory inputs = harness__.testBuildInputs(
                state,
                selector,
                indices
            );

            // Check the hashes because you can't compare dynamic arrays directly
            if (keccak256(inputs) != keccak256(calldata_)) {
                return false;
            }
        }

        return true;
    }

    /// @dev Should build inputs that match Math.add ABI
    function test_commandBuilderHarness1() public view {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Math.add.selector,
            0x01,
            bytes6(0x80ff00000000),
            bytes1(0x01),
            address(math__)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = command1;

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(uint256(2), uint256(1), uint256(2));

        uint256[] memory numbers = new uint256[](2);
        numbers[0] = 1;
        numbers[1] = 2;

        bytes memory calldata_ = abi.encodeWithSelector(
            Math.add.selector,
            numbers
        );

        require(
            executeBuildInputs(commands, state, calldata_),
            "buildInputs failed"
        );
    }

    /// @dev Should build inputs that match Strings.strcat ABI
    function test_commandBuilderHarness2() public view {
        bytes32 command1 = WeirollPlanner.buildCommand(
            Strings.strcat.selector,
            0x01,
            bytes6(0x8081ff000000),
            bytes1(0xff),
            address(strings__)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = command1;

        bytes[] memory state = new bytes[](2);
        state[0] = WeirollPlanner.stringToBytes("Hello, ");
        state[1] = WeirollPlanner.stringToBytes("world!");

        bytes memory calldata_ = abi.encodeWithSelector(
            Strings.strcat.selector,
            "Hello, ",
            "world!"
        );

        require(
            executeBuildInputs(commands, state, calldata_),
            "buildInputs failed"
        );
    }

    ///@dev Should build inputs that match Math.sum ABI
    function test_commandBuilderHarness3() public view {
        uint256[] memory numbers = new uint256[](3);

        numbers[0] = uint256(
            0xAAA0000000000000000000000000000000000000000000000000000000000002
        );
        numbers[1] = uint256(
            0x1111111111111111111111111111111111111111111111111111111111111111
        );
        numbers[2] = uint256(
            0x2222222222222222222222222222222222222222222222222222222222222222
        );

        bytes memory calldata_ = abi.encodeWithSelector(
            Math.sum.selector,
            numbers
        );

        bytes32 command1 = WeirollPlanner.buildCommand(
            Math.sum.selector,
            0x01,
            bytes6(0x80ff00000000),
            bytes1(0x01),
            address(math__)
        );

        bytes32[] memory commands = new bytes32[](1);
        commands[0] = command1;

        bytes[] memory state = new bytes[](2);

        state[0] = abi.encode(
            uint256(3),
            uint256(
                0xAAA0000000000000000000000000000000000000000000000000000000000002
            ),
            uint256(
                0x1111111111111111111111111111111111111111111111111111111111111111
            ),
            uint256(
                0x2222222222222222222222222222222222222222222222222222222222222222
            )
        );

        require(
            executeBuildInputs(commands, state, calldata_),
            "buildInputs failed"
        );
    }

    /// @dev Should select and overwrite first 32 byte slot in state for output (static test)
    function test_commandBuilderHarness4() public view {
        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(
            bytes32(
                0x000000000000000000000000000000000000000000000000000000000000000a
            )
        );
        state[1] = abi.encode(
            bytes32(
                0x1111111111111111111111111111111111111111111111111111111111111111
            )
        );
        state[2] = abi.encode(
            bytes32(
                0x2222222222222222222222222222222222222222222222222222222222222222
            )
        );

        bytes1 index = bytes1(0x00);

        bytes memory output = abi.encode(
            bytes32(
                0x0000000000000000000000000000000000000000000000000000000000000000
            )
        );

        (bytes[] memory outState, bytes memory outOutput) = harness__
            .testWriteOutputs(state, index, output);

        state[0] = output;

        require(
            keccak256(abi.encode(outState, outOutput)) ==
                keccak256(abi.encode(state, output)),
            "state not updated"
        );
    }

    /// @dev Should select and overwrite second dynamic amount bytes in second state slot given a uint[] output (dynamic test)
    function test_commandBuilderHarness5() public view {
        bytes[] memory state = new bytes[](3);

        state[0] = abi.encode(
            bytes32(
                0x000000000000000000000000000000000000000000000000000000000000000a
            )
        );
        state[1] = abi.encode(
            bytes32(
                0x1111111111111111111111111111111111111111111111111111111111111111
            )
        );
        state[2] = abi.encode(
            bytes32(
                0x2222222222222222222222222222222222222222222222222222222222222222
            )
        );

        bytes1 index = bytes1(0x81);

        // Need this for the 0x20 length check in writeOutputs
        uint256[] memory outputList = new uint256[](3);
        outputList[0] = 1;
        outputList[1] = 2;
        outputList[2] = 3;

        (bytes[] memory outState, ) = harness__.testWriteOutputs(
            state,
            index,
            abi.encode(outputList)
        );

        state[1] = abi.encode(uint256(3), uint256(1), uint256(2), uint256(3));

        require(
            keccak256(abi.encode(outState)) == keccak256(abi.encode(state)),
            "state not updated"
        );
    }

    /// @dev Should overwrite entire state with *abi decoded* output value (rawcall)
    function test_commandBuilderHarness6() public view {
        bytes[] memory state = new bytes[](3);

        state[0] = abi.encode(
            bytes32(
                0x000000000000000000000000000000000000000000000000000000000000000a
            )
        );
        state[1] = abi.encode(
            bytes32(
                0x1111111111111111111111111111111111111111111111111111111111111111
            )
        );
        state[2] = abi.encode(
            bytes32(
                0x2222222222222222222222222222222222222222222222222222222222222222
            )
        );

        bytes1 index = bytes1(0xfe);

        bytes[] memory precoded = new bytes[](3);
        precoded[0] = abi.encode(bytes1(0x11));
        precoded[1] = abi.encode(bytes1(0x22));
        precoded[2] = abi.encode(bytes1(0x33));

        bytes memory output = abi.encode(precoded);

        (bytes[] memory outState, bytes memory outOutput) = harness__
            .testWriteOutputs(state, index, output);

        require(
            keccak256(abi.encode(outState, outOutput)) ==
                keccak256(abi.encode(precoded, output)),
            "state not updated"
        );
    }
}
