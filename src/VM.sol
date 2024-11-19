// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {CommandBuilder} from "./CommandBuilder.sol";

/// @title VM
/// @notice The Weiroll Virtual Machine.
abstract contract VM {
    using CommandBuilder for bytes[];

    uint256 constant FLAG_CT_DELEGATECALL = 0x00;
    uint256 constant FLAG_CT_CALL = 0x01;
    uint256 constant FLAG_CT_STATICCALL = 0x02;
    uint256 constant FLAG_CT_VALUECALL = 0x03;
    uint256 constant FLAG_CT_MASK = 0x03;
    uint256 constant FLAG_VERBATIM = 0x20;
    uint256 constant FLAG_EXTENDED_COMMAND = 0x40;
    uint256 constant FLAG_TUPLE_RETURN = 0x80;

    uint256 constant SHORT_COMMAND_FILL = 0x000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    address immutable self;

    error ExecutionFailed(uint256 commandIndex, address target, string message);

    error ValueCallHasNoValue();

    error InvalidCallType();

    constructor() {
        self = address(this);
    }

    function _execute(bytes32[] calldata commands, bytes[] memory state) internal returns (bytes[] memory) {
        bytes32 command;
        uint256 flags;
        bytes32 indices;

        bool success;
        bytes memory outdata;

        uint256 commandsLength = commands.length;
        for (uint256 i; i < commandsLength;) {
            command = commands[i];
            flags = uint256(uint8(bytes1(command << 32)));

            if (flags & FLAG_EXTENDED_COMMAND != 0) {
                indices = commands[i++];
            } else {
                indices = bytes32(uint256(command << 40) | SHORT_COMMAND_FILL);
            }

            if (flags & FLAG_CT_MASK == FLAG_CT_DELEGATECALL) {
                bytes memory inputs = flags & FLAG_VERBATIM == 0
                    ? state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                    : state[uint8(bytes1(indices)) & CommandBuilder.IDX_VALUE_MASK];

                (success, outdata) = address(uint160(uint256(command))).delegatecall(inputs);
            } else if (flags & FLAG_CT_MASK == FLAG_CT_CALL) {
                bytes memory inputs = flags & FLAG_VERBATIM == 0
                    ? state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                    : state[uint8(bytes1(indices)) & CommandBuilder.IDX_VALUE_MASK];

                (success, outdata) = address(uint160(uint256(command))).call(inputs);
            } else if (flags & FLAG_CT_MASK == FLAG_CT_STATICCALL) {
                bytes memory inputs = flags & FLAG_VERBATIM == 0
                    ? state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                    : state[uint8(bytes1(indices)) & CommandBuilder.IDX_VALUE_MASK];

                (success, outdata) = address(uint160(uint256(command))).staticcall(inputs);
            } else if (flags & FLAG_CT_MASK == FLAG_CT_VALUECALL) {
                uint256 calleth;
                bytes memory v = state[uint8(bytes1(indices))];

                if (v.length != 32) {
                    revert ValueCallHasNoValue();
                }

                assembly {
                    calleth := mload(add(v, 0x20))
                }

                bytes memory inputs = flags & FLAG_VERBATIM == 0
                    ? state.buildInputs(
                        //selector
                        bytes4(command),
                        indices
                    )
                    : state[uint8(bytes1(indices)) & CommandBuilder.IDX_VALUE_MASK];

                (success, outdata) = address(uint160(uint256(command))).call{value: calleth}(inputs);
            } else {
                revert InvalidCallType();
            }

            if (!success) {
                // If `outdata` is longer than 68 bytes it is most likely an `Error(string)`.
                if (outdata.length > 68) {
                    assembly {
                        outdata := add(outdata, 68)
                    }
                }

                revert ExecutionFailed({
                    commandIndex: flags & FLAG_EXTENDED_COMMAND == 0 ? i : i - 1,
                    target: address(uint160(uint256(command))),
                    message: outdata.length > 0 ? string(outdata) : "Unknown"
                });
            }

            if (flags & FLAG_TUPLE_RETURN != 0) {
                state.writeTuple(bytes1(command << 88), outdata);
            } else {
                state = state.writeOutputs(bytes1(command << 88), outdata);
            }
            unchecked {
                ++i;
            }
        }
        return state;
    }
}
