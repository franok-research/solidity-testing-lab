// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/// @notice Minimal interface to the Foundry test VM. Avoids external dependencies.
interface Vm {
    function warp(uint256 newTimestamp) external;
    function expectRevert(bytes4 selector) external;
}

abstract contract VmTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
}
