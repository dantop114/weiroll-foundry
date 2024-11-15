// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.18;

/// @title EventsHelper
/// @notice Helper contract for emitting events
contract EventsHelper {
    /// @notice Emitted when a bytes array is logged
    /// @param data The bytes array
    event LogBytes(bytes data);

    /// @notice Emitted when a string is logged
    /// @param message The string
    event LogString(string message);

    /// @notice Emitted when a bytes32 is logged
    /// @param data The bytes32
    event LogBytes32(bytes32 data);

    /// @notice Emitted when a uint256 is logged
    /// @param message The uint256
    event LogUint(uint256 message);

    /// @notice Returns the version of this helper contract.
    function VERSION() public pure returns (string memory) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mstore(0x00, 0x20) // offset
            mstore(0x24, 0x0476302e31) // "v0.1"
            return(0x00, 0x60) // return 96 bytes
        }
    }

    /// @notice Logs a bytes array
    /// @param data The bytes array
    function logBytes(bytes calldata data) external {
        emit LogBytes(data);
    }

    /// @notice Logs a string
    /// @param message The string
    function logString(string calldata message) external {
        emit LogString(message);
    }

    /// @notice Logs a bytes32
    /// @param data The bytes32
    function logBytes32(bytes32 data) external {
        emit LogBytes32(data);
    }

    /// @notice Logs a uint256
    /// @param message The uint256
    function logUint(uint256 message) external {
        emit LogUint(message);
    }

    /// @notice Logs a topic using the `log1` opcode.
    /// @param topic The topic
    function logTopic(bytes32 topic) external {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            log1(0x00, 0x00, topic)
        }
    }

    /// @notice Logs a topic using the `log2` opcode.
    /// @param topic The topic
    /// @param indexed0 The first indexed value
    function logTopic(bytes32 topic, bytes32 indexed0) external {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            log2(0x00, 0x00, topic, indexed0)
        }
    }

    /// @notice Logs a topic using the `log3` opcode.
    /// @param topic The topic
    /// @param indexed0 The first indexed value
    /// @param indexed1 The second indexed value
    function logTopic(
        bytes32 topic,
        bytes32 indexed0,
        bytes32 indexed1
    ) external {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            log3(0x00, 0x00, topic, indexed0, indexed1)
        }
    }

    /// @notice Logs a topic using the `log4` opcode.
    /// @param topic The topic
    /// @param indexed0 The first indexed value
    /// @param indexed1 The second indexed value
    /// @param indexed2 The third indexed value
    function logTopic(
        bytes32 topic,
        bytes32 indexed0,
        bytes32 indexed1,
        bytes32 indexed2
    ) external {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            log4(0x00, 0x00, topic, indexed0, indexed1, indexed2)
        }
    }
}
