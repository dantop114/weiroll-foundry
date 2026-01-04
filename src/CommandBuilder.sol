// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

library CommandBuilder {
    uint256 constant IDX_VARIABLE_LENGTH = 0x80;
    uint256 constant IDX_VALUE_MASK = 0x7f;
    uint256 constant IDX_END_OF_ARGS = 0xff;
    uint256 constant IDX_USE_STATE = 0xfe;

    /// @dev Dynamic state variables must be a multiple of 32 bytes.
    error DynamicStateVariableLength();

    /// @dev Static state variables must be 32 bytes.
    error StaticStateVariableLength();

    /// @dev Only one return value permitted (variable).
    error MultipleReturnValueVariable();

    /// @dev Only one return value permitted (static).
    error MultipleReturnValueStatic();

    /// @dev Build the input data for a call.
    function buildInputs(bytes[] memory state, bytes4 selector, bytes32 indices)
        internal
        pure
        returns (bytes memory ret)
    {
        uint256 count; // Number of bytes in whole ABI encoded message
        uint256 free; // Pointer to first free byte in tail part of message
        bytes memory stateData; // Optionally encode the current state if the call requires it

        uint256 idx;

        // Determine the length of the encoded data
        for (uint256 i; i < 32;) {
            idx = uint8(indices[i]);

            if (idx == IDX_END_OF_ARGS) break;

            if (idx & IDX_VARIABLE_LENGTH != 0) {
                if (idx == IDX_USE_STATE) {
                    if (stateData.length == 0) {
                        stateData = abi.encode(state);
                    }

                    unchecked {
                        count += stateData.length;
                    }
                } else {
                    // Add the size of the value, rounded up to the next word boundary, plus space for pointer and length
                    uint256 arglen = state[idx & IDX_VALUE_MASK].length;
                    if (arglen % 32 != 0) revert DynamicStateVariableLength();

                    unchecked {
                        count += arglen + 32;
                    }
                }
            } else {
                if (state[idx & IDX_VALUE_MASK].length != 32) revert StaticStateVariableLength();

                unchecked {
                    count += 32;
                }
            }

            unchecked {
                free += 32;
                ++i;
            }
        }

        unchecked {
            ret = new bytes(count + 4);
        }

        assembly {
            mstore(add(ret, 0x20), selector)
        }

        count = 0;

        for (uint256 i; i < 32;) {
            idx = uint8(indices[i]);
            if (idx == IDX_END_OF_ARGS) break;

            if (idx & IDX_VARIABLE_LENGTH != 0) {
                if (idx == IDX_USE_STATE) {
                    assembly {
                        mstore(add(add(ret, 0x24), count), free)
                        let stateDataLen := sub(mload(stateData), 0x20)
                        mcopy(add(ret, add(free, 0x24)), add(stateData, 0x40), stateDataLen)
                        free := add(free, sub(stateDataLen, 0x20))
                    }
                } else {
                    // Variable length data; put a pointer in the slot and write the data at the end
                    assembly {
                        mstore(add(add(ret, 0x24), count), free)

                        // stateIndex = idx & IDX_VALUE_MASK
                        let stateIndex := and(idx, IDX_VALUE_MASK)

                        if lt(mload(state), stateIndex) {
                            // Revert with Panic(0x32) if the state index is out of bounds
                            mstore(0x00, 0x4e487b71)
                            mstore(0x20, 0x32)
                            revert(0x1c, 0x24)
                        }

                        // Get the pointer in the array
                        let statevar := mload(add(add(state, 0x20), shl(0x5, stateIndex)))
                        let arglen := mload(statevar)

                        mcopy(add(ret, add(free, 0x24)), add(statevar, 0x20), arglen)

                        free := add(free, arglen)
                    }
                }
            } else {
                // Fixed length data; write it directly
                assembly {
                    let stateIndex := and(idx, IDX_VALUE_MASK)

                    if lt(mload(state), stateIndex) {
                        // Revert with Panic(0x32) if the state index is out of bounds
                        mstore(0x00, 0x4e487b71)
                        mstore(0x20, 0x32)
                        revert(0x1c, 0x24)
                    }

                    let statevar := mload(add(add(state, 0x20), mul(stateIndex, 0x20)))

                    mstore(add(add(ret, 36), count), mload(add(statevar, 32)))
                }
            }
            unchecked {
                count += 32;
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Write the outputs of a call back to the state.
    function writeOutputs(bytes[] memory state, bytes1 index, bytes memory output)
        internal
        pure
        returns (bytes[] memory)
    {
        uint256 idx = uint8(index);
        if (idx == IDX_END_OF_ARGS) return state;

        if (idx & IDX_VARIABLE_LENGTH != 0) {
            if (idx == IDX_USE_STATE) {
                state = abi.decode(output, (bytes[]));
            } else {
                assembly {
                    let sizeptr := add(output, 0x20)
                    let argptr := mload(sizeptr)

                    if iszero(eq(argptr, 0x20)) {
                        // Revert with MultipleReturnValueVariable()
                        mstore(0x00, 0x082da2ea)
                        revert(0x1c, 0x04)
                    }

                    // Overwrite the first word of the return data with the length - 32
                    mstore(sizeptr, sub(mload(output), 0x20))

                    let stateIndex := and(idx, IDX_VALUE_MASK)

                    if lt(mload(state), stateIndex) {
                        // Revert with Panic(0x32) if the state index is out of bounds
                        mstore(0x00, 0x4e487b71)
                        mstore(0x20, 0x32)
                        revert(0x1c, 0x24)
                    }

                    // Insert a pointer to the return data, starting at the second word, into state
                    mstore(add(add(state, 0x20), shl(0x5, stateIndex)), sizeptr)
                }
            }
        } else {
            // Single word
            assembly {
                if iszero(eq(mload(output), 0x20)) {
                    // Revert with MultipleReturnValueStatic()
                    mstore(0x00, 0x43990615)
                    revert(0x1c, 0x04)
                }

                let stateIndex := and(idx, IDX_VALUE_MASK)

                if lt(mload(state), stateIndex) {
                    // Revert with Panic(0x32) if the state index is out of bounds
                    mstore(0x00, 0x4e487b71)
                    mstore(0x20, 0x32)
                    revert(0x1c, 0x24)
                }

                // Insert the return data into state
                mstore(add(add(state, 0x20), shl(0x5, stateIndex)), output)
            }
        }

        return state;
    }

    /// @dev Write a tuple to the state.
    function writeTuple(bytes[] memory state, bytes1 index, bytes memory output) internal pure {
        uint256 idx = uint256(uint8(index));
        if (idx == IDX_END_OF_ARGS) return;

        bytes memory entry = state[idx] = new bytes(output.length + 32);

        assembly {
            mcopy(add(add(entry, 0x20), 0x20), add(output, 0x20), mload(output))
            let l := mload(output)
            mstore(add(entry, 32), l)
        }
    }
}
