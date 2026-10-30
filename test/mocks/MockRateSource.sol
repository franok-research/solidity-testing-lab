// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IRateSource} from "../../src/BoundedRateOracle.sol";

/// @notice A freely mutable test-only source. Never use as a production price feed.
contract MockRateSource is IRateSource {
    uint256 private rate;
    uint256 private observedAt;

    constructor(uint256 initialRate, uint256 initialObservedAt) {
        rate = initialRate;
        observedAt = initialObservedAt;
    }

    function set(uint256 newRate, uint256 newObservedAt) external {
        rate = newRate;
        observedAt = newObservedAt;
    }

    function latestRate() external view override returns (uint256, uint256) {
        return (rate, observedAt);
    }
}
