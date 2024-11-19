// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

library WeirollPlanner {
    function stringToBytes(string memory input) internal pure returns (bytes memory output) {
        // This is for sure ugly, let's see if we can do better
        assembly {
            output := mload(0x40)

            // Get the length of the input string
            let strlen := mload(input)

            // Round up the string length to the nearest 32 bytes multiple
            // So that we're padding out the output to the right length
            let blen := and(add(strlen, 0x1f), not(0x1f))

            // This is the total length of the output
            let olen := add(blen, 0x20)

            // Store the length of the output in the first word
            mstore(output, olen)

            // Store the length of the string in the second word
            mstore(add(output, 0x20), strlen)

            // Copy the string data into the output
            mcopy(add(output, 0x40), add(input, 0x20), strlen)
            // Zero out the rest of the output using the zero word at 0x80 (https://docs.soliditylang.org/en/latest/internals/layout_in_memory.html#layout-in-memory)
            mcopy(add(output, add(0x40, strlen)), 0x80, sub(blen, strlen))

            mstore(0x40, add(add(output, 0x20), olen))
        }
    }

    function buildCommand(bytes4 _selector, bytes1 _flags, bytes6 _input, bytes1 _output, address _target)
        internal
        pure
        returns (bytes32)
    {
        uint256 selector = uint256(bytes32(_selector));
        uint256 flags = uint256(uint8(_flags)) << 216;
        uint256 input = uint256(uint48(_input)) << 168;
        uint256 output = uint256(uint8(_output)) << 160;
        uint256 target = uint256(uint160(_target));

        return bytes32(selector ^ flags ^ input ^ output ^ target);
    }
}
