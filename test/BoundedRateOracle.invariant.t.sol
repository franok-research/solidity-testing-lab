// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoundedRateOracle} from "../src/BoundedRateOracle.sol";
import {MockRateSource} from "./mocks/MockRateSource.sol";
import {VmTest} from "./utils/Vm.sol";

/// @notice Stateful handler for invariant campaigns: always submits a valid,
///         fresh observation after enough time has elapsed.
contract RateHandler is VmTest {
    MockRateSource public feed;
    BoundedRateOracle public oracle;
    uint256 public precedingRate;
    uint256 public resultingRate;
    uint256 public steps;

    constructor() {
        feed = new MockRateSource(1e18, block.timestamp);
        oracle = new BoundedRateOracle(address(feed), 1e18, 500, 60, 120);
    }

    function step(uint128 seed) external {
        uint256 beforeRate = oracle.lastRate();
        vm.warp(block.timestamp + 60);
        uint256 rawRate = 1 + uint256(seed) % 1e30;
        feed.set(rawRate, block.timestamp);
        uint256 afterRate = oracle.refresh();

        precedingRate = beforeRate;
        resultingRate = afterRate;
        steps += 1;
    }
}

/// @notice Fuzzes sequences of valid observations rather than isolated calls.
contract BoundedRateOracleInvariantTest {
    RateHandler internal handler;

    function setUp() public {
        handler = new RateHandler();
    }

    /// @dev Foundry discovers targetContracts() and restricts invariant calls
    ///      to the handler, not to the read-only mock/oracle getters.
    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function invariant_PositiveAndWithinConfiguredDomain() public view {
        uint256 current = handler.oracle().lastRate();
        assert(current > 0);
        assert(current <= handler.oracle().MAX_RATE());
    }

    function invariant_LastSuccessfulTransitionBounded() public view {
        if (handler.steps() == 0) return;
        uint256 prior = handler.precedingRate();
        uint256 current = handler.resultingRate();
        uint256 allowance = prior * handler.oracle().maxMoveBps() / 10_000;
        assert(current >= prior - allowance);
        assert(current <= prior + allowance);
        assert(current == handler.oracle().lastRate());
    }

    function invariant_ClockNotInFuture() public view {
        assert(handler.oracle().lastUpdatedAt() <= block.timestamp);
    }
}
