// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoundedRateOracle} from "../src/BoundedRateOracle.sol";
import {MockRateSource} from "./mocks/MockRateSource.sol";
import {VmTest} from "./utils/Vm.sol";

contract BoundedRateOracleTest is VmTest {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant INTERVAL = 1 hours;
    uint256 internal constant AGE = 2 hours;
    uint256 internal constant MOVE_BPS = 500; // five percent per eligible refresh

    MockRateSource internal feed;
    BoundedRateOracle internal oracle;

    function setUp() public {
        feed = new MockRateSource(ONE, block.timestamp);
        oracle = new BoundedRateOracle(address(feed), ONE, MOVE_BPS, INTERVAL, AGE);
    }

    function _ready() internal {
        vm.warp(block.timestamp + INTERVAL);
    }

    function test_InitialState() public view {
        assert(oracle.lastRate() == ONE);
        assert(oracle.maxMoveBps() == MOVE_BPS);
        assert(address(oracle.source()) == address(feed));
    }

    function test_RevertIfTooEarly() public {
        vm.expectRevert(BoundedRateOracle.UpdateTooSoon.selector);
        oracle.refresh();
    }

    function test_CapUpwardSpike() public {
        _ready();
        feed.set(2 * ONE, block.timestamp);
        assert(oracle.refresh() == 1_050_000_000_000_000_000);
    }

    function test_CapDownwardSpike() public {
        _ready();
        feed.set(ONE / 2, block.timestamp);
        assert(oracle.refresh() == 950_000_000_000_000_000);
    }

    function test_PassThroughInRange() public {
        _ready();
        feed.set(1_020_000_000_000_000_000, block.timestamp);
        assert(oracle.refresh() == 1_020_000_000_000_000_000);
    }

    function test_ExactlyAtUpperBound() public {
        _ready();
        feed.set(1_050_000_000_000_000_000, block.timestamp);
        assert(oracle.refresh() == 1_050_000_000_000_000_000);
    }

    function test_RevertOnZeroRate() public {
        _ready();
        feed.set(0, block.timestamp);
        vm.expectRevert(BoundedRateOracle.InvalidRate.selector);
        oracle.refresh();
    }

    function test_RevertOnOutOfRangeRate() public {
        _ready();
        feed.set(oracle.MAX_RATE() + 1, block.timestamp);
        vm.expectRevert(BoundedRateOracle.InvalidRate.selector);
        oracle.refresh();
    }

    function test_RevertOnStaleSource() public {
        vm.warp(block.timestamp + AGE + 1);
        vm.expectRevert(BoundedRateOracle.InvalidSourceTimestamp.selector);
        oracle.refresh();
    }

    function test_RevertOnFutureSourceTimestamp() public {
        _ready();
        feed.set(ONE, block.timestamp + 1);
        vm.expectRevert(BoundedRateOracle.InvalidSourceTimestamp.selector);
        oracle.refresh();
    }

    function test_RevertOnMissingTimestamp() public {
        _ready();
        feed.set(ONE, 0);
        vm.expectRevert(BoundedRateOracle.InvalidSourceTimestamp.selector);
        oracle.refresh();
    }

    function test_AllowedAtExactAgeLimit() public {
        vm.warp(block.timestamp + AGE);
        assert(oracle.refresh() == ONE);
    }

    function test_RepeatedUpwardUpdatesAreRateLimited() public {
        _ready();
        feed.set(2 * ONE, block.timestamp);
        assert(oracle.refresh() == 1_050_000_000_000_000_000);
        vm.expectRevert(BoundedRateOracle.UpdateTooSoon.selector);
        oracle.refresh();
        _ready();
        feed.set(2 * ONE, block.timestamp);
        assert(oracle.refresh() == 1_102_500_000_000_000_000);
        assert(oracle.lastUpdatedAt() == block.timestamp);
    }

    function test_RevertOnBadConstructorInputs() public {
        vm.expectRevert(BoundedRateOracle.InvalidSource.selector);
        new BoundedRateOracle(address(0), ONE, MOVE_BPS, INTERVAL, AGE);
        vm.expectRevert(BoundedRateOracle.InvalidRate.selector);
        new BoundedRateOracle(address(feed), 0, MOVE_BPS, INTERVAL, AGE);
        vm.expectRevert(BoundedRateOracle.InvalidConfiguration.selector);
        new BoundedRateOracle(address(feed), ONE, 10_001, INTERVAL, AGE);
        vm.expectRevert(BoundedRateOracle.InvalidConfiguration.selector);
        new BoundedRateOracle(address(feed), ONE, MOVE_BPS, 0, AGE);
    }

    function testFuzz_RateCannotEscapeStepBounds(uint128 rawSeed) public {
        _ready();
        uint256 rawRate = 1 + uint256(rawSeed) % oracle.MAX_RATE();
        feed.set(rawRate, block.timestamp);
        uint256 rate = oracle.refresh();
        uint256 allowance = ONE * MOVE_BPS / oracle.BPS();
        assert(rate >= ONE - allowance);
        assert(rate <= ONE + allowance);
        assert(rate > 0);
    }

    function testFuzz_BoundsHoldForDifferentLimits(uint16 bpsSeed, uint128 rawSeed) public {
        uint256 bps = 1 + uint256(bpsSeed) % 5_000;
        BoundedRateOracle variableLimit = new BoundedRateOracle(address(feed), ONE, bps, INTERVAL, AGE);
        _ready();
        uint256 rawRate = 1 + uint256(rawSeed) % variableLimit.MAX_RATE();
        feed.set(rawRate, block.timestamp);
        uint256 rate = variableLimit.refresh();
        uint256 allowance = ONE * bps / variableLimit.BPS();
        assert(rate >= ONE - allowance && rate <= ONE + allowance);
    }
}
