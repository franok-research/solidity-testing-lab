// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/// @notice A minimal rate source used only in this self-contained demonstration.
interface IRateSource {
    function latestRate() external view returns (uint256 rate, uint256 observedAt);
}

/// @title BoundedRateOracle
/// @notice Demonstrates input validation, freshness checks and per-update rate limits.
/// @dev Educational example, NOT a secure production oracle or a substitute for audits.
///      It deliberately does not attempt to validate source integrity or market prices.
contract BoundedRateOracle {
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_RATE = 1e36;
    uint256 public constant MAX_MOVE_BPS = 5_000;
    uint256 public constant MAX_PERIOD = 30 days;

    IRateSource public immutable source;
    uint256 public immutable maxMoveBps;
    uint256 public immutable minUpdateInterval;
    uint256 public immutable maxSourceAge;

    uint256 public lastRate;
    uint256 public lastUpdatedAt;

    error InvalidSource();
    error InvalidConfiguration();
    error InvalidRate();
    error UpdateTooSoon();
    error InvalidSourceTimestamp();

    event RateRefreshed(uint256 rawRate, uint256 boundedRate, uint256 sourceObservedAt);

    constructor(
        address source_,
        uint256 initialRate_,
        uint256 maxMoveBps_,
        uint256 minUpdateInterval_,
        uint256 maxSourceAge_
    ) {
        if (source_ == address(0) || source_.code.length == 0) revert InvalidSource();
        if (initialRate_ == 0 || initialRate_ > MAX_RATE) revert InvalidRate();
        if (
            maxMoveBps_ == 0 || maxMoveBps_ > MAX_MOVE_BPS
                || minUpdateInterval_ == 0 || minUpdateInterval_ > MAX_PERIOD
                || maxSourceAge_ == 0 || maxSourceAge_ > MAX_PERIOD
        ) revert InvalidConfiguration();

        source = IRateSource(source_);
        maxMoveBps = maxMoveBps_;
        minUpdateInterval = minUpdateInterval_;
        maxSourceAge = maxSourceAge_;
        lastRate = initialRate_;
        lastUpdatedAt = block.timestamp;
    }

    /// @notice Returns the next bounded rate, updating state at most once per interval.
    /// @dev Up and down limits are symmetrical; small integer rates may round to zero
    ///      allowed movement. Repeated refreshes can converge toward a persistent
    ///      extreme source value: the cooldown is essential to this example's model.
    function refresh() external returns (uint256 boundedRate) {
        if (block.timestamp - lastUpdatedAt < minUpdateInterval) revert UpdateTooSoon();

        (uint256 rawRate, uint256 observedAt) = source.latestRate();
        if (rawRate == 0 || rawRate > MAX_RATE) revert InvalidRate();
        if (
            observedAt == 0 || observedAt > block.timestamp
                || block.timestamp - observedAt > maxSourceAge
        ) revert InvalidSourceTimestamp();

        uint256 prior = lastRate;
        uint256 allowance = prior * maxMoveBps / BPS;
        uint256 lower = prior - allowance;
        uint256 upper = prior + allowance;

        boundedRate = rawRate < lower ? lower : (rawRate > upper ? upper : rawRate);
        lastRate = boundedRate;
        lastUpdatedAt = block.timestamp;
        emit RateRefreshed(rawRate, boundedRate, observedAt);
    }
}
